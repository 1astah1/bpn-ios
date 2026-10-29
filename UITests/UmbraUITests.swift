import XCTest

/// Проход по основным экранам со скриншотами.
/// Ссылка подписки — из окружения: `TEST_RUNNER_SUBSCRIPTION_URL=... xcodebuild test`, в репозиторий её не кладём.
final class UmbraUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // Одно и то же «устройство» во всех прогонах — не съедаем лимит устройств тестовой подписки.
        app.launchEnvironment["UMBRA_TEST_HWID"] = "umbra-uitest-0001"
    }

    func testMainFlow() throws {
        let subscription = try XCTUnwrap(
            ProcessInfo.processInfo.environment["SUBSCRIPTION_URL"],
            "Нет SUBSCRIPTION_URL — передай TEST_RUNNER_SUBSCRIPTION_URL"
        )
        app.launch()

        // Сначала экран про данные (App Review 5.4), потом ссылка подписки.
        let accept = app.buttons["Понятно, продолжить"]
        if accept.waitForExistence(timeout: 3) {
            snapshot("00-privacy")
            accept.tap()
        }

        // Онбординг: при прошлом прогоне подписка могла остаться — тогда сразу главный экран.
        let field = app.textFields.firstMatch
        if field.waitForExistence(timeout: 3) {
            sleep(1)
            snapshot("01-onboarding")
            field.tap()
            field.typeText(subscription)
            app.buttons["Добавить"].tap()
        }

        let picker = app.buttons["server-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 30), "Главный экран не открылся")
        sleep(1)
        snapshot("02-home")

        picker.tap()
        XCTAssertTrue(app.navigationBars["Серверы"].waitForExistence(timeout: 5))
        sleep(1)
        snapshot("03-servers")

        app.buttons["Замерить пинг"].tap()
        let measured = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' мс' OR label == 'нет ответа'")).firstMatch
        XCTAssertTrue(measured.waitForExistence(timeout: 40), "Скорость серверов не показалась")
        app.navigationBars["Серверы"].swipeUp()
        sleep(1)
        snapshot("04-servers-ping")
        app.buttons["Готово"].tap()

        app.buttons["Настройки"].tap()
        XCTAssertTrue(app.navigationBars["Настройки"].waitForExistence(timeout: 5))
        snapshot("05-settings")
        app.buttons["Готово"].tap()

        // В симуляторе туннель не поднимается — смотрим, что пользователь увидит при ошибке.
        app.buttons["Подключить"].tap()
        // Перед первым системным запросом VPN — пояснение (ревью требует объяснить, что с данными).
        let proceed = app.buttons["Продолжить"]
        XCTAssertTrue(proceed.waitForExistence(timeout: 5), "Нет пояснения перед запросом VPN")
        sleep(1)
        snapshot("06-vpn-explainer")
        proceed.tap()
        sleep(3)
        snapshot("06b-connect-attempt")

        // Вид «подключено» — через отладочный флаг, туннель в симуляторе не работает.
        app.terminate()
        app.launchArguments = ["-demo-connected"]
        app.launch()
        XCTAssertTrue(app.buttons["server-picker"].waitForExistence(timeout: 10))
        sleep(2)
        snapshot("07-home-connected")
    }

    /// Путь проверяющего Apple: экран данных → конфиг vless:// → главный → пинг → пояснение перед VPN.
    /// Ссылка — `TEST_RUNNER_REVIEW_LINK`; без неё тест пропускается.
    func testReviewFlow() throws {
        guard let link = ProcessInfo.processInfo.environment["REVIEW_LINK"], !link.isEmpty else {
            throw XCTSkip("Нет REVIEW_LINK — сценарий проверяющего пропущен")
        }
        app.launchArguments = ["-reset-state"]
        app.launch()

        let accept = app.buttons["Понятно, продолжить"]
        XCTAssertTrue(accept.waitForExistence(timeout: 5))
        snapshot("r1-privacy")
        accept.tap()

        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(link)
        snapshot("r2-paste")
        app.buttons["Добавить"].tap()

        let picker = app.buttons["server-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 15), "Главный экран не открылся")
        sleep(1)
        snapshot("r3-home")

        picker.tap()
        XCTAssertTrue(app.navigationBars["Серверы"].waitForExistence(timeout: 5))
        app.buttons["Замерить пинг"].tap()
        let measured = app.staticTexts.matching(NSPredicate(format: "label ENDSWITH ' мс' OR label == 'нет ответа'")).firstMatch
        XCTAssertTrue(measured.waitForExistence(timeout: 30))
        sleep(1)
        snapshot("r4-servers")
        app.buttons["Готово"].tap()
        sleep(1)
        snapshot("r5-home-ping")

        app.buttons["Подключить"].tap()
        XCTAssertTrue(app.buttons["Продолжить"].waitForExistence(timeout: 5))
        sleep(1)
        snapshot("r6-vpn-explainer")
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
