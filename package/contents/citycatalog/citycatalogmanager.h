#pragma once

#include <QObject>
#include <QNetworkAccessManager>
#include <QDateTime>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include <memory>

class QNetworkReply;
class QLockFile;

class CityCatalogManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariantList cities READ cities NOTIFY citiesChanged)
    Q_PROPERTY(QVariantList uniqueCities READ uniqueCities NOTIFY citiesChanged)
    Q_PROPERTY(QString version READ version NOTIFY versionChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString logFilePath READ logFilePath CONSTANT)

public:
    explicit CityCatalogManager(QObject *parent = nullptr);
    ~CityCatalogManager() override;

    QVariantList cities() const;
    QVariantList uniqueCities() const;
    QString version() const;
    QString status() const;
    QString logFilePath() const;

    Q_INVOKABLE void start();
    Q_INVOKABLE void logEvent(const QString &category, const QString &message);
    Q_INVOKABLE QString openPlasmaJournal();

    // Returns the city's own current local wall-clock string, formatted
    // byte-identically to main.qml::formatSystemLocalClock (same date/time/
    // timezone format choices and the "  \u00b7  " separator), differing only
    // in the zone used. Returns an EMPTY QString for an empty or invalid IANA
    // id so the QML side falls back to the existing system-local path (never
    // blank, never "Invalid Date").
    //
    // CORRECTNESS TRAP: a raw QDateTime handed back to QML would be re-formatted
    // by Qt.formatTime/Qt.formatDateTime in the SYSTEM-LOCAL zone, silently
    // undoing the zone conversion. We therefore assemble the full string here in
    // C++ and return a finished QString. The live clock is read on every call,
    // so the tooltip recomputes when shown.
    Q_INVOKABLE QString formatZonedClock(const QString &ianaId, int dateFormat,
                                         int timeFormat, int timezoneFormat,
                                         const QString &localeName) const;

    // Pure, deterministic helper that formats a GIVEN UTC instant for the given
    // zone/format. formatZonedClock() calls this with the current UTC instant.
    // Exposed (static) so the QTest can pin the conversion with fixed instants.
    static QString formatZonedClockAt(const QDateTime &utcInstant, const QString &ianaId,
                                       int dateFormat, int timeFormat, int timezoneFormat,
                                       const QString &localeName);

signals:
    void citiesChanged();
    void versionChanged();
    void statusChanged();

private:
    void setStatus(const QString &status);
    void continueStart();
    void checkForUpdate();
    void downloadAsset(const QUrl &url, const QByteArray &digest, const QString &version);
    void handleFailure(const QString &message);
    void updateLastChecked();
    QString cachePath() const;

    QNetworkAccessManager m_network;
    QVariantList m_cities;
    QVariantList m_uniqueCities;
    QString m_version;
    QString m_status;
    QString m_cachePath;
    QDateTime m_lastCheckedAt;
    QNetworkReply *m_activeReply = nullptr;
    std::unique_ptr<QLockFile> m_lock;
    bool m_started = false;
    bool m_waitingForUpdater = false;
};
