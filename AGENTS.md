# AGENTS.md — client_ios (iOS / iPadOS / tvOS)

Нативный клиент FreePlex на Swift + SwiftUI. Цель: красивый, стабильный, тестируемый плеер и навигация. Сначала прочитай корневой [../AGENTS.md](../AGENTS.md) и [../docs/clients.md](../docs/clients.md).

## Стек

- **Swift** (последняя стабильная), **SwiftUI** для UI, без Storyboard.
- **Swift Concurrency** (`async/await`, `actor`) для сети и состояния.
- **AVFoundation / AVPlayer** для воспроизведения (HLS нативно, HW-декод).
- Сетевой слой — **сгенерированный SDK** из OpenAPI (Apple `swift-openapi-generator` предпочтительно).
- Таргеты: `FreePlex` (iOS/iPadOS) и `FreePlex TV` (tvOS) в одном проекте с общим ядром (Swift Package с фичами/моделями/SDK).

## Архитектура

```
client_ios/
├── FreePlex.xcodeproj (или Package.swift + app targets)
├── Packages/
│   └── Core/                # общий код: модели, SDK-обёртка, ViewModels
│       ├── Networking/      # SDK + APIClient (адрес сервера, токены)
│       ├── Features/        # по фичам: Library, Details, Player, Settings
│       └── DesignSystem/    # цвета, типографика, компоненты
├── App-iOS/                 # iOS/iPadOS entry + экраны
└── App-tvOS/                # tvOS entry + focus-раскладки
```

- Паттерн: **MVVM**. `View` (SwiftUI) ↔ `@Observable`/`ObservableObject` ViewModel ↔ Repository (SDK + кэш).
- ViewModel не знает про SwiftUI; зависимости инжектируются через протоколы (тестируемость).
- Хранение токенов — Keychain. Адрес сервера — UserDefaults/AppStorage.

## Плеер

- `AVPlayer` + `AVPlayerViewController` (iOS) / SwiftUI-обёртка; на tvOS — родной плеер с focus.
- Перед стартом: `POST /playback/decision` с device profile (кодеки h264/hevc, HDR по устройству, разрешение).
- Открываем URL (DirectPlay) или HLS (`index.m3u8`).
- Выбор аудио/субтитров через `AVMediaSelectionGroup`.
- **Выбор качества:** UI-селектор со списком `availableQualities`. Auto → `master.m3u8` (нативный ABR). Manual → фиксировать через `preferredPeakBitRate` / `preferredMaximumResolution`. Смена на лету: `set-quality` + подмена item + seek на позицию.
- **Сеть/кап:** раздельные капы для Wi-Fi и сотовой; тип сети через `NWPathMonitor`; на сотовой — умеренный кап по умолчанию, подставлять `maxBitrateKbps` в профиль.
- **Нестабильная сеть:** полагаться на ABR (понижение качества вместо паузы); индикатор буферизации; повтор с backoff при обрыве.
- Прогресс: периодически `PUT /progress` + при паузе/выходе; resume по возврату.

## Device profile (пример)

Определять из возможностей устройства: HEVC поддерживается на A9+; HDR — по `AVPlayer`/дисплею; максимальное разрешение — 4K на актуальных Apple TV/устройствах.

## Конвенции

- SwiftLint + SwiftFormat, предупреждения = ошибки в CI.
- Никаких force-unwrap в проде (кроме явно доказанных мест).
- Асинхронность только через Swift Concurrency, без завершающих замыканий в новом коде.

## Контроль ресурсов (CPU/ОЗУ)

- Освобождать `AVPlayer` и его item при уходе с плеера/в фон (`replaceCurrentItem(with: nil)`), снимать observers.
- Изображения через `AsyncImage`/кэш с downsampling под размер ячейки; ограничить `URLCache`; не держать полноразмерные постеры в памяти для сетки.
- Ленивые `LazyVGrid`/`LazyVStack`; отменять запросы при исчезновении вью (`task`/`.task` с cancellation).
- Никаких таймеров/поллинга на неактивных экранах; прогресс слать по событиям и разумному интервалу.
- Профилировать Instruments (Allocations/Leaks); особое внимание бюджету памяти на Apple TV.

## Тестирование

- **XCTest** для ViewModels и парсинга/маппинга (замоканный APIClient через протоколы).
- Snapshot-тесты ключевых экранов (опционально, `swift-snapshot-testing`).
- UI-тесты критических путей: логин → библиотека → детали → плей.
- Ручной чек-лист воспроизведения (DirectPlay/Transcode/seek/субтитры) на iPhone и Apple TV перед релизом.

## Definition of Done

- Собирается для iOS и tvOS, линтеры/тесты зелёные.
- Экран работает с реальным сервером (dev) и на моках.
- Обновлены модели при изменении API (регенерация SDK).
