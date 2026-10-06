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
    Q_PROPERTY(QString version READ version NOTIFY versionChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString logFilePath READ logFilePath CONSTANT)

public:
    explicit CityCatalogManager(QObject *parent = nullptr);
    ~CityCatalogManager() override;

    QVariantList cities() const;
    QString version() const;
    QString status() const;
    QString logFilePath() const;

    Q_INVOKABLE void start();
    Q_INVOKABLE void logEvent(const QString &category, const QString &message);
    Q_INVOKABLE QString openPlasmaJournal();

signals:
    void citiesChanged();
    void versionChanged();
    void statusChanged();

private:
    void setStatus(const QString &status);
    void checkForUpdate();
    void downloadAsset(const QUrl &url, const QByteArray &digest, const QString &version);
    void handleFailure(const QString &message);
    void updateLastChecked();
    QString cachePath() const;

    QNetworkAccessManager m_network;
    QVariantList m_cities;
    QString m_version;
    QString m_status;
    QString m_cachePath;
    QDateTime m_lastCheckedAt;
    QNetworkReply *m_activeReply = nullptr;
    std::unique_ptr<QLockFile> m_lock;
    bool m_started = false;
    bool m_waitingForUpdater = false;
};
