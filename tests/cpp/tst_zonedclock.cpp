#include <QtTest/QtTest>
#include <QDateTime>
#include <QTimeZone>

#include "citycatalogmanager.h"

// Pins CityCatalogManager::formatZonedClockAt — the pure zone-conversion helper
// behind the formatZonedClock Q_INVOKABLE — against fixed instants so the
// city-pin tooltip format can never drift from main.qml's clock badge.
//
// Format-choice constants (mirroring Plasmoid.configuration):
//   dateFormat:     0 Short, 1 Long, 2 ISO (yyyy-MM-dd)
//   timeFormat:     0 HH:mm, 1 h:mm AP, 2 HH:mm:ss, 3 h:mm:ss AP
//   timezoneFormat: 0 hidden, 1 abbreviation, 2 full name
class TestZonedClock : public QObject
{
    Q_OBJECT

private slots:
    void kolkataNoDst();
    void tokyoDateRollover();
    void londonSummerAbbrev();
    void invalidIdReturnsEmpty();
    void emptyIdReturnsEmpty();
    void twelveHourUppercaseAmPm();
    void utcOffsetFormats();
    void fractionalUtcOffsetFormats();
    void invalidUtcOffsetReturnsEmpty();
};

void TestZonedClock::kolkataNoDst()
{
    // Asia/Kolkata is UTC+5:30 year-round (no DST). 11:09Z + 5:30 => 16:39 same day.
    const QDateTime utc(QDate(2024, 1, 15), QTime(11, 9, 0), QTimeZone::UTC);
    const QString result = CityCatalogManager::formatZonedClockAt(
        utc, QStringLiteral("Asia/Kolkata"), 2 /*ISO*/, 0 /*HH:mm*/, 0 /*hidden*/, QStringLiteral("en_US"));
    QCOMPARE(result, QStringLiteral("2024-01-15  \u00b7  16:39"));
}

void TestZonedClock::tokyoDateRollover()
{
    // Asia/Tokyo is UTC+9. 2024-01-15T18:05:09Z + 9h => 2024-01-16T03:05:09 local.
    const QDateTime utc(QDate(2024, 1, 15), QTime(18, 5, 9), QTimeZone::UTC);
    const QString result = CityCatalogManager::formatZonedClockAt(
        utc, QStringLiteral("Asia/Tokyo"), 2 /*ISO*/, 2 /*HH:mm:ss*/, 0 /*hidden*/, QStringLiteral("en_US"));
    QCOMPARE(result, QStringLiteral("2024-01-16  \u00b7  03:05:09"));
}

void TestZonedClock::londonSummerAbbrev()
{
    // Europe/London observes BST (UTC+1) in July.
    const QDateTime utc(QDate(2024, 7, 15), QTime(12, 0, 0), QTimeZone::UTC);
    const QString result = CityCatalogManager::formatZonedClockAt(
        utc, QStringLiteral("Europe/London"), 2 /*ISO*/, 0 /*HH:mm*/, 1 /*abbrev*/, QStringLiteral("en_US"));
    QVERIFY2(result.endsWith(QStringLiteral(" BST")),
             qPrintable(QStringLiteral("expected trailing ' BST', got: %1").arg(result)));
    // 12:00Z + 1h BST => 13:00 local.
    QVERIFY2(result.startsWith(QStringLiteral("2024-07-15  \u00b7  13:00")),
             qPrintable(result));
}

void TestZonedClock::invalidIdReturnsEmpty()
{
    const QDateTime utc(QDate(2024, 1, 15), QTime(11, 9, 0), QTimeZone::UTC);
    const QString result = CityCatalogManager::formatZonedClockAt(
        utc, QStringLiteral("Not/AZone"), 2, 0, 0, QStringLiteral("en_US"));
    QVERIFY(result.isEmpty());
}

void TestZonedClock::emptyIdReturnsEmpty()
{
    const QDateTime utc(QDate(2024, 1, 15), QTime(11, 9, 0), QTimeZone::UTC);
    const QString result = CityCatalogManager::formatZonedClockAt(
        utc, QString(), 2, 0, 0, QStringLiteral("en_US"));
    QVERIFY(result.isEmpty());
}

void TestZonedClock::twelveHourUppercaseAmPm()
{
    // Asia/Kolkata +5:30. 11:09Z => 16:39 local => 4:39 PM (no leading zero, uppercase).
    const QDateTime utc(QDate(2024, 1, 15), QTime(11, 9, 0), QTimeZone::UTC);
    const QString result = CityCatalogManager::formatZonedClockAt(
        utc, QStringLiteral("Asia/Kolkata"), 2 /*ISO*/, 1 /*h:mm AP*/, 0 /*hidden*/, QStringLiteral("en_US"));
    QCOMPARE(result, QStringLiteral("2024-01-15  \u00b7  4:39 PM"));
}

void TestZonedClock::utcOffsetFormats()
{
    const QDateTime utc(QDate(2024, 7, 15), QTime(12, 0, 0), QTimeZone::UTC);
    QCOMPARE(CityCatalogManager::formatUtcOffsetAt(
                 utc, QStringLiteral("Europe/London"), 0),
             QStringLiteral("+1"));
    QCOMPARE(CityCatalogManager::formatUtcOffsetAt(
                 utc, QStringLiteral("Europe/London"), 1),
             QStringLiteral("+1:00 UTC"));
    QCOMPARE(CityCatalogManager::formatUtcOffsetAt(
                 utc, QStringLiteral("Europe/London"), 2),
             QStringLiteral("+01:00"));
}

void TestZonedClock::fractionalUtcOffsetFormats()
{
    const QDateTime utc(QDate(2024, 1, 15), QTime(11, 9, 0), QTimeZone::UTC);
    QCOMPARE(CityCatalogManager::formatUtcOffsetAt(
                 utc, QStringLiteral("Asia/Kolkata"), 0),
             QStringLiteral("+5:30"));
    QCOMPARE(CityCatalogManager::formatUtcOffsetAt(
                 utc, QStringLiteral("Asia/Kolkata"), 1),
             QStringLiteral("+5:30 UTC"));
    QCOMPARE(CityCatalogManager::formatUtcOffsetAt(
                 utc, QStringLiteral("Asia/Kolkata"), 2),
             QStringLiteral("+05:30"));
}

void TestZonedClock::invalidUtcOffsetReturnsEmpty()
{
    const QDateTime utc(QDate(2024, 1, 15), QTime(11, 9, 0), QTimeZone::UTC);
    QVERIFY(CityCatalogManager::formatUtcOffsetAt(
                utc, QStringLiteral("Not/AZone"), 1).isEmpty());
    QVERIFY(CityCatalogManager::formatUtcOffsetAt(
                utc, QStringLiteral("Asia/Kolkata"), 3).isEmpty());
}

QTEST_MAIN(TestZonedClock)
#include "tst_zonedclock.moc"
