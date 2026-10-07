#include "citycatalogmanager.h"

#include <QDateTime>
#include <QDir>
#include <QLocale>
#include <QTimeZone>
#include <QCryptographicHash>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QProcess>
#include <QSaveFile>
#include <QSharedPointer>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>
#include <QtConcurrent/QtConcurrentRun>
#include <QFutureWatcher>
#include <QLockFile>

#include <zlib.h>

#include <algorithm>
#include <cmath>
#include <limits>

namespace {
constexpr int MinimumPopulation = 10000;
constexpr qsizetype MaximumCompressedSize = 32 * 1024 * 1024;
constexpr qsizetype MaximumExpandedSize = 128 * 1024 * 1024;
constexpr qint64 MaximumLogSize = 1024 * 1024;

struct CatalogResult {
    QVariantList cities;
    QVariantList uniqueCities;
    QString error;
};

struct CachedCatalogResult {
    CatalogResult catalog;
    QString version;
    QDateTime lastCheckedAt;
    QString readError;
    QString validationError;
    bool valid = false;
};

double distanceKm(double leftLatitude, double leftLongitude,
                  double rightLatitude, double rightLongitude)
{
    constexpr double radians = 3.14159265358979323846 / 180.0;
    const double latitudeDelta = (rightLatitude - leftLatitude) * radians;
    const double longitudeDelta = (rightLongitude - leftLongitude) * radians;
    const double haversine = std::pow(std::sin(latitudeDelta / 2), 2)
            + std::cos(leftLatitude * radians) * std::cos(rightLatitude * radians)
            * std::pow(std::sin(longitudeDelta / 2), 2);
    const double safeHaversine = std::clamp(haversine, 0.0, 1.0);
    return 6371.0 * 2 * std::atan2(std::sqrt(safeHaversine), std::sqrt(1 - safeHaversine));
}

QVariantList uniqueCities(const QVariantList &cities)
{
    QHash<QString, QList<QVariantMap>> grouped;
    for (const QVariant &value : cities) {
        const QVariantMap city = value.toMap();
        const QString key = (city.value(QStringLiteral("name")).toString()
                             + QChar(0)
                             + city.value(QStringLiteral("country")).toString()).toCaseFolded();
        QList<QVariantMap> &sameName = grouped[key];
        const double latitude = city.value(QStringLiteral("latitude")).toDouble();
        const double longitude = city.value(QStringLiteral("longitude")).toDouble();
        auto duplicate = std::find_if(sameName.begin(), sameName.end(), [&](const QVariantMap &existing) {
            return distanceKm(existing.value(QStringLiteral("latitude")).toDouble(),
                              existing.value(QStringLiteral("longitude")).toDouble(),
                              latitude, longitude) < 2.0;
        });
        if (duplicate == sameName.end()) {
            sameName.append(city);
        } else if (city.value(QStringLiteral("population")).toInt()
                   > duplicate->value(QStringLiteral("population")).toInt()) {
            *duplicate = city;
        }
    }

    QVariantList result;
    result.reserve(cities.size());
    for (const QList<QVariantMap> &sameName : grouped) {
        for (const QVariantMap &city : sameName) {
            result.append(city);
        }
    }
    std::sort(result.begin(), result.end(), [](const QVariant &left, const QVariant &right) {
        const QVariantMap leftCity = left.toMap();
        const QVariantMap rightCity = right.toMap();
        const int nameOrder = QString::localeAwareCompare(
            leftCity.value(QStringLiteral("name")).toString(),
            rightCity.value(QStringLiteral("name")).toString());
        return nameOrder < 0 || (nameOrder == 0 && QString::localeAwareCompare(
            leftCity.value(QStringLiteral("country")).toString(),
            rightCity.value(QStringLiteral("country")).toString()) < 0);
    });
    return result;
}

CachedCatalogResult readCatalogCache(const QString &path)
{
    CachedCatalogResult result;
    QFile cache(path);
    if (!cache.open(QIODevice::ReadOnly)) {
        result.readError = cache.errorString();
        return result;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(cache.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        result.validationError = QStringLiteral("Invalid JSON: %1").arg(parseError.errorString());
        return result;
    }

    const QJsonObject root = document.object();
    const QJsonArray cityArray = root.value(QStringLiteral("cities")).toArray();
    result.version = root.value(QStringLiteral("sourceVersion")).toString();
    result.lastCheckedAt = QDateTime::fromString(
        root.value(QStringLiteral("lastCheckedAt")).toString(), Qt::ISODate);
    result.valid = !cityArray.isEmpty() && !result.version.isEmpty();
    for (const QJsonValue &value : cityArray) {
        const QJsonObject city = value.toObject();
        const double latitude = city.value(QStringLiteral("latitude")).toDouble(-1000);
        const double longitude = city.value(QStringLiteral("longitude")).toDouble(-1000);
        if (!value.isObject() || city.value(QStringLiteral("cityId")).toString().isEmpty()
            || city.value(QStringLiteral("name")).toString().isEmpty()
            || city.value(QStringLiteral("country")).toString().isEmpty()
            || !std::isfinite(latitude) || latitude < -90 || latitude > 90
            || !std::isfinite(longitude) || longitude < -180 || longitude > 180) {
            result.valid = false;
            break;
        }
    }

    if (!result.valid) {
        result.validationError = QStringLiteral("City cache has no valid city records");
        return result;
    }
    result.catalog.cities = cityArray.toVariantList();
    result.catalog.uniqueCities = uniqueCities(result.catalog.cities);
    return result;
}

bool decompressGzip(const QByteArray &compressed, QByteArray *expanded, QString *error)
{
    z_stream stream{};
    stream.next_in = reinterpret_cast<Bytef *>(const_cast<char *>(compressed.constData()));
    stream.avail_in = static_cast<uInt>(compressed.size());
    if (inflateInit2(&stream, MAX_WBITS + 16) != Z_OK) {
        *error = QStringLiteral("Unable to initialize gzip decompression");
        return false;
    }

    QByteArray chunk(64 * 1024, Qt::Uninitialized);
    int result = Z_OK;
    while (result == Z_OK) {
        stream.next_out = reinterpret_cast<Bytef *>(chunk.data());
        stream.avail_out = static_cast<uInt>(chunk.size());
        result = inflate(&stream, Z_NO_FLUSH);
        expanded->append(chunk.constData(), chunk.size() - stream.avail_out);
        if (expanded->size() > MaximumExpandedSize) {
            *error = QStringLiteral("Expanded city export exceeds the size limit");
            inflateEnd(&stream);
            return false;
        }
    }
    inflateEnd(&stream);
    if (result != Z_STREAM_END) {
        *error = QStringLiteral("City export is not a valid gzip archive");
        return false;
    }
    return true;
}

bool parseCsv(const QByteArray &csv, QVariantList *cities, QString *error)
{
    const QList<QByteArray> requiredColumns{
        "id", "name", "country_name", "latitude", "longitude", "timezone", "population"
    };
    QHash<QByteArray, int> columns;
    QList<QString> fields;
    QByteArray field;
    bool quoted = false;
    bool firstRow = true;
    QSet<QString> ids;

    auto finishField = [&] {
        fields.append(QString::fromUtf8(field));
        field.clear();
    };

    auto finishRow = [&]() -> bool {
        if (firstRow) {
            for (qsizetype index = 0; index < fields.size(); ++index) {
                columns.insert(fields.at(index).toUtf8(), static_cast<int>(index));
            }
            for (const QByteArray &required : requiredColumns) {
                if (!columns.contains(required)) {
                    *error = QStringLiteral("City export is missing column: %1")
                                 .arg(QString::fromUtf8(required));
                    return false;
                }
            }
            firstRow = false;
        } else if (!fields.isEmpty()) {
            auto value = [&](const char *column) -> QString {
                const int index = columns.value(QByteArray(column), -1);
                return index >= 0 && index < fields.size() ? fields.at(index).trimmed() : QString();
            };

            bool populationOk = false;
            const int population = value("population").toInt(&populationOk);
            bool latitudeOk = false;
            bool longitudeOk = false;
            const double latitude = value("latitude").toDouble(&latitudeOk);
            const double longitude = value("longitude").toDouble(&longitudeOk);
            const QString id = value("id");
            const QString name = value("name");
            const QString country = value("country_name");

            if (populationOk && population >= MinimumPopulation
                && latitudeOk && longitudeOk && std::isfinite(latitude) && std::isfinite(longitude)
                && latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
                && !id.isEmpty() && !name.isEmpty() && !country.isEmpty()) {
                if (ids.contains(id)) {
                    *error = QStringLiteral("Duplicate city ID in upstream export: %1").arg(id);
                    return false;
                }
                ids.insert(id);
                QVariantMap city{
                    {QStringLiteral("cityId"), id},
                    {QStringLiteral("name"), name},
                    {QStringLiteral("country"), country},
                    {QStringLiteral("latitude"), latitude},
                    {QStringLiteral("longitude"), longitude},
                    {QStringLiteral("timezone"), value("timezone")},
                    {QStringLiteral("population"), population}
                };
                cities->append(city);
            }
        }
        fields.clear();
        return true;
    };

    for (qsizetype index = 0; index < csv.size(); ++index) {
        const char character = csv.at(index);
        if (quoted) {
            if (character == '"') {
                if (index + 1 < csv.size() && csv.at(index + 1) == '"') {
                    field.append('"');
                    ++index;
                } else {
                    quoted = false;
                }
            } else {
                field.append(character);
            }
        } else if (character == '"' && field.isEmpty()) {
            quoted = true;
        } else if (character == ',') {
            finishField();
        } else if (character == '\n' || character == '\r') {
            finishField();
            if (!finishRow()) {
                return false;
            }
            if (character == '\r' && index + 1 < csv.size() && csv.at(index + 1) == '\n') {
                ++index;
            }
        } else {
            field.append(character);
        }
    }

    if (quoted) {
        *error = QStringLiteral("City export ends inside a quoted CSV field");
        return false;
    }
    if (!field.isEmpty() || !fields.isEmpty()) {
        finishField();
        if (!finishRow()) {
            return false;
        }
    }
    if (cities->isEmpty()) {
        *error = QStringLiteral("City export contains no valid cities");
        return false;
    }
    return true;
}

CatalogResult parseExport(const QByteArray &compressed)
{
    CatalogResult result;
    QByteArray expanded;
    if (!decompressGzip(compressed, &expanded, &result.error)) {
        return result;
    }
    parseCsv(expanded, &result.cities, &result.error);
    if (result.error.isEmpty()) {
        result.uniqueCities = uniqueCities(result.cities);
    }
    return result;
}
}

CityCatalogManager::CityCatalogManager(QObject *parent)
    : QObject(parent)
{
    m_cachePath = QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
                      .filePath(QStringLiteral("subsolar-world-map/cities.json"));
}

CityCatalogManager::~CityCatalogManager() = default;

QVariantList CityCatalogManager::cities() const
{
    return m_cities;
}

QVariantList CityCatalogManager::uniqueCities() const
{
    return m_uniqueCities;
}

QString CityCatalogManager::version() const
{
    return m_version;
}

QString CityCatalogManager::status() const
{
    return m_status;
}

QString CityCatalogManager::logFilePath() const
{
    return QDir(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation))
        .filePath(QStringLiteral("subsolar-world-map/subsolar-world-map.log"));
}

void CityCatalogManager::logEvent(const QString &category, const QString &message)
{
    const QString directory = QFileInfo(logFilePath()).absolutePath();
    if (!QDir().mkpath(directory)) {
        qWarning().noquote() << "SubSolar World Map cannot create diagnostics directory:" << directory;
        return;
    }

    QLockFile lock(logFilePath() + QStringLiteral(".lock"));
    if (!lock.tryLock(1000)) {
        qWarning().noquote() << "SubSolar World Map cannot lock diagnostics log:" << logFilePath();
        return;
    }

    QFile logFile(logFilePath());
    if (logFile.exists() && logFile.size() >= MaximumLogSize) {
        const QString backupPath = logFilePath() + QStringLiteral(".1");
        if (QFile::exists(backupPath) && !QFile::remove(backupPath)) {
            qWarning().noquote() << "SubSolar World Map cannot rotate diagnostics log:" << backupPath;
            return;
        }
        if (!QFile::rename(logFilePath(), backupPath)) {
            qWarning().noquote() << "SubSolar World Map cannot rotate diagnostics log:" << logFilePath();
            return;
        }
    }

    if (!logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        qWarning().noquote() << "SubSolar World Map cannot open diagnostics log:"
                             << logFilePath() << logFile.errorString();
        return;
    }
    const QByteArray line = QStringLiteral("%1 [SubSolar %2] %3\n")
                                .arg(QDateTime::currentDateTime().toString(Qt::ISODateWithMs),
                                     category,
                                     message)
                                .toUtf8();
    if (logFile.write(line) != line.size() || !logFile.flush()) {
        qWarning().noquote() << "SubSolar World Map cannot write diagnostics log:"
                             << logFilePath() << logFile.errorString();
    }
}

QString CityCatalogManager::openPlasmaJournal()
{
    const QString journalctl = QStandardPaths::findExecutable(QStringLiteral("journalctl"));
    if (journalctl.isEmpty()) {
        const QString error = QStringLiteral("journalctl could not be found");
        logEvent(QStringLiteral("journal/error"), error);
        return error;
    }

    const QStringList journalArguments{
        QStringLiteral("--user"),
        QStringLiteral("--since=15 minutes ago"),
        QStringLiteral("--follow"),
        QStringLiteral("_COMM=plasmashell")
    };
    const QString konsole = QStandardPaths::findExecutable(QStringLiteral("konsole"));
    if (!konsole.isEmpty()) {
        QStringList terminalArguments{
            QStringLiteral("--hold"),
            QStringLiteral("--title"),
            QStringLiteral("SubSolar World Map Journal"),
            QStringLiteral("-e"),
            journalctl
        };
        terminalArguments.append(journalArguments);
        if (QProcess::startDetached(konsole, terminalArguments)) {
            logEvent(QStringLiteral("journal"),
                     QStringLiteral("Opened Plasma user journal in Konsole"));
            return {};
        }
    }

    const QString terminalLauncher =
        QStandardPaths::findExecutable(QStringLiteral("xdg-terminal-exec"));
    if (!terminalLauncher.isEmpty()) {
        QStringList terminalArguments{
            QStringLiteral("--hold"),
            QStringLiteral("--title=SubSolar World Map Journal"),
            QStringLiteral("--"),
            journalctl
        };
        terminalArguments.append(journalArguments);
        if (QProcess::startDetached(terminalLauncher,
                                    terminalArguments,
                                    QString(),
                                    nullptr)) {
            logEvent(QStringLiteral("journal"),
                     QStringLiteral("Opened Plasma user journal in the configured terminal"));
            return {};
        }
    }

    const QString error =
        QStringLiteral("Could not open a terminal for the journal. Install Konsole or configure "
                       "a working xdg-terminal-exec launcher, or run "
                       "journalctl --user --since=\"15 minutes ago\" --follow _COMM=plasmashell "
                       "in a terminal.");
    logEvent(QStringLiteral("journal/error"), error);
    return error;
}

QString CityCatalogManager::formatZonedClockAt(const QDateTime &utcInstant, const QString &ianaId,
                                               int dateFormat, int timeFormat, int timezoneFormat,
                                               const QString &localeName)
{
    if (ianaId.isEmpty()) {
        return QString();
    }
    const QTimeZone zone(ianaId.toUtf8());
    if (!zone.isValid()) {
        return QString();
    }

    const QDateTime dt = utcInstant.toTimeZone(zone);
    const QLocale locale(localeName);

    // Date segment, matching main.qml::formatSystemLocalClock:
    //   0 => ShortFormat, 2 => ISO yyyy-MM-dd, default/1 => LongFormat.
    QString dateText;
    switch (dateFormat) {
    case 0:
        dateText = locale.toString(dt.date(), QLocale::ShortFormat);
        break;
    case 2:
        dateText = dt.date().toString(QStringLiteral("yyyy-MM-dd"));
        break;
    default:
        dateText = locale.toString(dt.date(), QLocale::LongFormat);
        break;
    }

    // Time segment. The four patterns ARE Qt format strings, so dt.toString()
    // reproduces main.qml's Qt.formatTime(dateTime, pattern) output byte-for-byte.
    static const QString timePatterns[] = {
        QStringLiteral("HH:mm"),
        QStringLiteral("h:mm AP"),
        QStringLiteral("HH:mm:ss"),
        QStringLiteral("h:mm:ss AP")
    };
    const QString timePattern =
        (timeFormat >= 0 && timeFormat < 4) ? timePatterns[timeFormat] : timePatterns[0];

    // Separator literal: two spaces, middot (U+00B7), two spaces.
    QString clockText = dateText + QStringLiteral("  \u00b7  ") + dt.toString(timePattern);

    // Timezone segment, matching main.qml: 1 => abbreviation (Qt "t"),
    // 2 => full name (Qt "tttt"). QTimeZone's abbreviation/displayName are the
    // DST-aware equivalents for an arbitrary zone at this instant.
    switch (timezoneFormat) {
    case 1:
        clockText += QLatin1Char(' ') + zone.abbreviation(dt);
        break;
    case 2:
        clockText += QLatin1Char(' ') + zone.displayName(dt, QTimeZone::LongName, locale);
        break;
    default:
        break;
    }

    return clockText;
}

QString CityCatalogManager::formatZonedClock(const QString &ianaId, int dateFormat,
                                             int timeFormat, int timezoneFormat,
                                             const QString &localeName) const
{
    return formatZonedClockAt(QDateTime::currentDateTimeUtc(), ianaId, dateFormat,
                              timeFormat, timezoneFormat, localeName);
}

void CityCatalogManager::setStatus(const QString &status)
{
    if (m_status == status) {
        return;
    }
    logEvent(QStringLiteral("city catalog"), QStringLiteral("Status: %1").arg(status));
    m_status = status;
    emit statusChanged();
}

QString CityCatalogManager::cachePath() const
{
    return m_cachePath;
}

void CityCatalogManager::start()
{
    if (m_started) {
        return;
    }
    m_started = true;

    const QFileInfo cacheInfo(cachePath());
    logEvent(QStringLiteral("city catalog"),
             QStringLiteral("Starting; cache path: %1 (%2)")
                 .arg(cachePath(), cacheInfo.exists() ? QStringLiteral("exists")
                                                      : QStringLiteral("not found")));
    if (cacheInfo.exists()) {
        setStatus(QStringLiteral("Loading cached city list…"));
        auto *watcher = new QFutureWatcher<CachedCatalogResult>(this);
        connect(watcher, &QFutureWatcher<CachedCatalogResult>::finished, this, [this, watcher] {
            const CachedCatalogResult result = watcher->result();
            watcher->deleteLater();
            if (!result.readError.isEmpty()) {
                handleFailure(QStringLiteral("Unable to read city cache: %1").arg(result.readError));
                return;
            }
            if (result.valid) {
                m_cities = result.catalog.cities;
                m_uniqueCities = result.catalog.uniqueCities;
                m_version = result.version;
                m_lastCheckedAt = result.lastCheckedAt;
                emit citiesChanged();
                emit versionChanged();
                setStatus(QStringLiteral("%1 cities available (catalog %2)")
                              .arg(m_cities.size()).arg(m_version));
                logEvent(QStringLiteral("city catalog"),
                         QStringLiteral("Loaded %1 cached city records and prepared %2 unique entries; version %3")
                             .arg(m_cities.size()).arg(m_uniqueCities.size()).arg(m_version));
            } else {
                logEvent(QStringLiteral("city catalog/error"),
                         QStringLiteral("City cache is invalid; downloading a fresh copy: %1")
                             .arg(result.validationError));
            }
            continueStart();
        });
        const QString path = cachePath();
        watcher->setFuture(QtConcurrent::run([path] {
            return readCatalogCache(path);
        }));
        return;
    } else {
        setStatus(QStringLiteral("Downloading city list for first use…"));
    }

    continueStart();
}

void CityCatalogManager::continueStart()
{
    const qint64 secondsSinceCheck = m_lastCheckedAt.isValid()
                                         ? m_lastCheckedAt.secsTo(QDateTime::currentDateTimeUtc())
                                         : -1;
    if (secondsSinceCheck >= 0 && secondsSinceCheck < 6 * 60 * 60 && !m_cities.isEmpty()) {
        logEvent(QStringLiteral("city catalog"),
                 QStringLiteral("Startup check skipped; last check was %1 seconds ago")
                     .arg(secondsSinceCheck));
        return;
    }

    const QString cacheDirectory = QFileInfo(cachePath()).absolutePath();
    if (!QDir().mkpath(cacheDirectory)) {
        handleFailure(QStringLiteral("Unable to create city cache directory: %1").arg(cacheDirectory));
        return;
    }

    m_lock = std::make_unique<QLockFile>(cachePath() + QStringLiteral(".lock"));
    if (!m_lock->tryLock(0)) {
        if (!m_waitingForUpdater) {
            logEvent(QStringLiteral("city catalog"),
                     QStringLiteral("Another applet instance owns the updater lock"));
        }
        m_waitingForUpdater = true;
        if (m_cities.isEmpty()) {
            setStatus(QStringLiteral("Another applet instance is downloading the city list"));
            QTimer::singleShot(1500, this, [this] {
                m_started = false;
                start();
            });
        }
        return;
    }
    m_waitingForUpdater = false;
    checkForUpdate();
}

void CityCatalogManager::checkForUpdate()
{
    logEvent(QStringLiteral("city catalog"),
             QStringLiteral("Checking latest GitHub release metadata"));
    QNetworkRequest request(QUrl(QStringLiteral(
        "https://api.github.com/repos/dr5hn/countries-states-cities-database/releases/latest")));
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("SubSolarWorldMap"));
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setTransferTimeout(30000);
    m_activeReply = m_network.get(request);
    connect(m_activeReply, &QNetworkReply::finished, this, [this] {
        QNetworkReply *reply = m_activeReply;
        m_activeReply = nullptr;
        const int httpStatus = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray response = reply->readAll();
        if (reply->error() != QNetworkReply::NoError || httpStatus < 200 || httpStatus >= 300) {
            const QString message = QStringLiteral("Unable to check city catalog release (%1)")
                                        .arg(reply->errorString());
            reply->deleteLater();
            handleFailure(message);
            return;
        }
        reply->deleteLater();

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(response, &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            handleFailure(QStringLiteral("GitHub returned invalid release metadata"));
            return;
        }
        const QJsonObject release = document.object();
        const QString releaseVersion = release.value(QStringLiteral("tag_name")).toString();
        logEvent(QStringLiteral("city catalog"),
                 QStringLiteral("Latest release: %1 | HTTP %2").arg(releaseVersion).arg(httpStatus));
        const QJsonArray assets = release.value(QStringLiteral("assets")).toArray();
        for (const QJsonValue &assetValue : assets) {
            const QJsonObject asset = assetValue.toObject();
            if (asset.value(QStringLiteral("name")).toString() != QStringLiteral("csv-cities.csv.gz")) {
                continue;
            }
            const QString digest = asset.value(QStringLiteral("digest")).toString();
            const QUrl downloadUrl(asset.value(QStringLiteral("browser_download_url")).toString());
            if (releaseVersion.isEmpty() || !downloadUrl.isValid()
                || downloadUrl.scheme() != QStringLiteral("https")
                || downloadUrl.host() != QStringLiteral("github.com")
                || !digest.startsWith(QStringLiteral("sha256:"))
                || digest.size() != 71) {
                handleFailure(QStringLiteral("City release metadata is missing version, download URL, or SHA-256 digest"));
                return;
            }
            if (releaseVersion == m_version && !m_cities.isEmpty()) {
                updateLastChecked();
                logEvent(QStringLiteral("city catalog"),
                         QStringLiteral("Cached catalog is current: %1").arg(m_version));
                setStatus(QStringLiteral("%1 cities available (catalog %2; up to date)")
                              .arg(m_cities.size()).arg(m_version));
                m_lock.reset();
                return;
            }
            setStatus(m_cities.isEmpty()
                          ? QStringLiteral("Downloading city catalog %1…").arg(releaseVersion)
                          : QStringLiteral("Updating city catalog to %1 in the background…").arg(releaseVersion));
            downloadAsset(downloadUrl, digest.mid(7).toLatin1(), releaseVersion);
            return;
        }
        handleFailure(QStringLiteral("Latest city release has no csv-cities.csv.gz asset"));
    });
}

void CityCatalogManager::downloadAsset(const QUrl &url, const QByteArray &digest, const QString &version)
{
    logEvent(QStringLiteral("city catalog"),
             QStringLiteral("Downloading release %1 from %2").arg(version, url.host()));
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute,
                         QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("SubSolarWorldMap"));
    request.setTransferTimeout(120000);
    m_activeReply = m_network.get(request);
    const QSharedPointer<QByteArray> compressed = QSharedPointer<QByteArray>::create();
    QNetworkReply *reply = m_activeReply;
    connect(reply, &QIODevice::readyRead, this, [reply, compressed] {
        const qint64 bytesToRead = MaximumCompressedSize + 1 - compressed->size();
        compressed->append(reply->read(bytesToRead));
        if (compressed->size() > MaximumCompressedSize) {
            reply->abort();
        }
    });
    connect(m_activeReply, &QNetworkReply::finished, this, [this, compressed, digest, version] {
        QNetworkReply *reply = m_activeReply;
        m_activeReply = nullptr;
        compressed->append(reply->readAll());
        if (reply->error() != QNetworkReply::NoError) {
            const QString message = compressed->size() > MaximumCompressedSize
                                        ? QStringLiteral("Downloaded city archive exceeds the size limit")
                                        : QStringLiteral("Unable to download city catalog: %1")
                                              .arg(reply->errorString());
            reply->deleteLater();
            handleFailure(message);
            return;
        }
        reply->deleteLater();
        if (compressed->isEmpty() || compressed->size() > MaximumCompressedSize) {
            handleFailure(QStringLiteral("Downloaded city archive has an invalid size"));
            return;
        }
        logEvent(QStringLiteral("city catalog"),
                 QStringLiteral("Downloaded %1 compressed bytes; verifying SHA-256")
                     .arg(compressed->size()));
        if (QCryptographicHash::hash(*compressed, QCryptographicHash::Sha256).toHex() != digest) {
            handleFailure(QStringLiteral("Downloaded city archive failed SHA-256 verification"));
            return;
        }

        auto *watcher = new QFutureWatcher<CatalogResult>(this);
        logEvent(QStringLiteral("city catalog"),
                 QStringLiteral("Archive verified; parsing CSV in background"));
        connect(watcher, &QFutureWatcher<CatalogResult>::finished, this, [this, watcher, version] {
            const CatalogResult result = watcher->result();
            watcher->deleteLater();
            if (!result.error.isEmpty()) {
                handleFailure(result.error);
                return;
            }

            QJsonArray cities;
            for (const QVariant &city : result.cities) {
                cities.append(QJsonObject::fromVariantMap(city.toMap()));
            }
            QJsonObject catalog{
                {QStringLiteral("source"), QStringLiteral("Countries States Cities Database")},
                {QStringLiteral("sourceVersion"), version},
                {QStringLiteral("minimumPopulation"), MinimumPopulation},
                {QStringLiteral("lastCheckedAt"), QDateTime::currentDateTimeUtc().toString(Qt::ISODate)},
                {QStringLiteral("cities"), cities}
            };
            QSaveFile cache(cachePath());
            if (!cache.open(QIODevice::WriteOnly)) {
                handleFailure(QStringLiteral("Unable to write city cache: %1").arg(cache.errorString()));
                return;
            }
            if (cache.write(QJsonDocument(catalog).toJson(QJsonDocument::Compact)) < 0
                || !cache.commit()) {
                handleFailure(QStringLiteral("Unable to atomically save city cache: %1").arg(cache.errorString()));
                return;
            }

            m_cities = result.cities;
            m_uniqueCities = result.uniqueCities;
            m_version = version;
            emit citiesChanged();
            emit versionChanged();
            setStatus(QStringLiteral("%1 cities available (catalog %2)")
                          .arg(m_cities.size()).arg(m_version));
            logEvent(QStringLiteral("city catalog"),
                     QStringLiteral("Saved catalog version %1 with %2 cities to %3")
                         .arg(m_version).arg(m_cities.size()).arg(cachePath()));
            m_lock.reset();
        });
        watcher->setFuture(QtConcurrent::run([compressed] {
            return parseExport(*compressed);
        }));
    });
}

void CityCatalogManager::updateLastChecked()
{
    QFile cacheFile(cachePath());
    if (!cacheFile.open(QIODevice::ReadOnly)) {
        logEvent(QStringLiteral("city catalog/error"),
                 QStringLiteral("Cannot update catalog check timestamp: %1")
                     .arg(cacheFile.errorString()));
        return;
    }
    QJsonParseError parseError;
    QJsonDocument document = QJsonDocument::fromJson(cacheFile.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
        logEvent(QStringLiteral("city catalog/error"),
                 QStringLiteral("Cannot update timestamp in invalid city cache"));
        return;
    }
    QJsonObject root = document.object();
    root.insert(QStringLiteral("lastCheckedAt"),
                QDateTime::currentDateTimeUtc().toString(Qt::ISODate));
    QSaveFile cache(cachePath());
    if (!cache.open(QIODevice::WriteOnly)) {
        logEvent(QStringLiteral("city catalog/error"),
                 QStringLiteral("Cannot open city cache to update check timestamp: %1")
                     .arg(cache.errorString()));
        return;
    }
    const QByteArray data = QJsonDocument(root).toJson(QJsonDocument::Compact);
    if (cache.write(data) != data.size() || !cache.commit()) {
        logEvent(QStringLiteral("city catalog/error"),
                 QStringLiteral("Cannot save catalog check timestamp: %1")
                     .arg(cache.errorString()));
    } else {
        m_lastCheckedAt = QDateTime::currentDateTimeUtc();
    }
}

void CityCatalogManager::handleFailure(const QString &message)
{
    logEvent(QStringLiteral("city catalog/error"), message);
    m_lock.reset();
    setStatus(m_cities.isEmpty()
                  ? QStringLiteral("City catalog unavailable: %1").arg(message)
                  : QStringLiteral("%1 (using cached catalog %2)")
                        .arg(message, m_version));
}
