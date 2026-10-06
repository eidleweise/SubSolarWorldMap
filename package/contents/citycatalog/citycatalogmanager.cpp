#include "citycatalogmanager.h"

#include <QDateTime>
#include <QDir>
#include <QCryptographicHash>
#include <QFile>
#include <QFileInfo>
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

#include <cmath>
#include <limits>

namespace {
constexpr int MinimumPopulation = 10000;
constexpr qsizetype MaximumCompressedSize = 32 * 1024 * 1024;
constexpr qsizetype MaximumExpandedSize = 128 * 1024 * 1024;
constexpr qint64 MaximumLogSize = 1024 * 1024;

struct CatalogResult {
    QVariantList cities;
    QString error;
};

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
        QFile cache(cachePath());
        if (!cache.open(QIODevice::ReadOnly)) {
            handleFailure(QStringLiteral("Unable to read city cache: %1").arg(cache.errorString()));
            return;
        }
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(cache.readAll(), &parseError);
        if (parseError.error == QJsonParseError::NoError && document.isObject()) {
            const QJsonObject root = document.object();
            const QJsonArray cityArray = root.value(QStringLiteral("cities")).toArray();
            bool validCache = !cityArray.isEmpty()
                              && !root.value(QStringLiteral("sourceVersion")).toString().isEmpty();
            for (const QJsonValue &value : cityArray) {
                const QJsonObject city = value.toObject();
                bool latitudeOk = false;
                bool longitudeOk = false;
                const double latitude = city.value(QStringLiteral("latitude")).toDouble(-1000);
                const double longitude = city.value(QStringLiteral("longitude")).toDouble(-1000);
                latitudeOk = std::isfinite(latitude) && latitude >= -90 && latitude <= 90;
                longitudeOk = std::isfinite(longitude) && longitude >= -180 && longitude <= 180;
                if (!value.isObject() || city.value(QStringLiteral("cityId")).toString().isEmpty()
                    || city.value(QStringLiteral("name")).toString().isEmpty()
                    || city.value(QStringLiteral("country")).toString().isEmpty()
                    || !latitudeOk || !longitudeOk) {
                    validCache = false;
                    break;
                }
            }
            if (validCache) {
                m_cities = cityArray.toVariantList();
                m_version = root.value(QStringLiteral("sourceVersion")).toString();
                m_lastCheckedAt = QDateTime::fromString(
                    root.value(QStringLiteral("lastCheckedAt")).toString(), Qt::ISODate);
                emit citiesChanged();
                emit versionChanged();
                setStatus(QStringLiteral("%1 cities available (catalog %2)")
                              .arg(m_cities.size()).arg(m_version));
                logEvent(QStringLiteral("city catalog"),
                         QStringLiteral("Loaded %1 cached city records; version %2")
                             .arg(m_cities.size()).arg(m_version));
            } else {
                logEvent(QStringLiteral("city catalog/error"),
                         QStringLiteral("City cache has no valid city records; downloading a fresh copy"));
            }
        } else {
            logEvent(QStringLiteral("city catalog/error"),
                     QStringLiteral("City cache is invalid; downloading a fresh copy: %1")
                         .arg(parseError.errorString()));
        }
    } else {
        setStatus(QStringLiteral("Downloading city list for first use…"));
    }

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
