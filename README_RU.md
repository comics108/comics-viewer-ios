# ComicsViewer Swift Package

Автономный Swift Package для отображения интерактивных комиксов и пазлов на iOS и macOS.

## Возможности

- **Рендеринг комиксов**: Отображение анимированных комиксов с автоматической прокруткой и синхронизацией звука
- **Поддержка пазлов**: Рендеринг интерактивных сеток пазлов с навигацией по кусочкам
- **Воспроизведение звука**: Аудио синхронизированное с позицией прокрутки с эффектами fade
- **Тайловые изображения**: Эффективное использование памяти с CATiledLayer (тайлы 512x512)
- **Анимации**: Анимации прозрачности, перемещения, масштаба, вращения и звука с кубической интерполяцией
- **Кросс-платформенность**: Совместимость с iOS 13.0+, macOS 10.15+
- **Только локальные файлы**: Работает с локальными .comics файлами (ZIP архивы), без сетевых зависимостей
- **Простой API**: Всего 5 основных методов для управления воспроизведением комиксов

## Установка

### Swift Package Manager

**1. Добавить в проект Xcode:**

- File → Add Package Dependencies
- Add Local → выберите `libs/comics_viewer/comics-viewer-ios`
- Свяжите `ComicsViewer` с вашим target

**2. Или добавьте в Package.swift:**

```swift
dependencies: [
    .package(path: "../путь/к/comics-viewer-ios")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: ["ComicsViewer"]
    )
]
```

## Быстрый старт

```swift
import UIKit
import ComicsViewer

class ComicsViewController: UIViewController {
    private let scrollView = ImageScrollView()
    private var controller: ComicsViewerController!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(scrollView)
        scrollView.frame = view.bounds

        controller = ComicsViewerController(scrollView: scrollView)

        controller.loadComics(filePath: "/путь/к/episode.comics") { result in
            switch result {
            case .success:
                self.controller.play()
            case .failure(let error):
                print("Ошибка: \(error)")
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        controller.dispose()
    }
}
```

## Публичный API

### ComicsViewerController

Главный контроллер для воспроизведения комиксов (упрощённый API, соответствующий Android/Flutter/React Native).

#### Методы

**1. Загрузка и отображение**

```swift
controller.loadComics(filePath: String, completion: @escaping (Result<Void, Error>) -> Void)

// Пример
controller.loadComics(filePath: comicsPath) { result in
    switch result {
    case .success:
        print("Комикс загружен!")
    case .failure(let error):
        print("Ошибка: \(error)")
    }
}
```

**2. Управление воспроизведением**

```swift
// Запустить авто-прокрутку
controller.play()

// Поставить на паузу
controller.pause()
```

**3. Навигация**

```swift
// Установить позицию прокрутки (от 0.0 до duration)
controller.setScrollPosition(500.0)

// Получить текущую позицию прокрутки
let position = controller.getScrollPosition()
```

**4. Превью и звук**

```swift
// Переключить видимость превью слоёв
controller.togglePreview(true)   // Показать превью
controller.togglePreview(false)  // Скрыть превью

// Переключить воспроизведение звука
controller.toggleSounds(true)    // Включить звуки
controller.toggleSounds(false)   // Выключить звуки
```

**5. Язык и очистка**

```swift
// Установить язык (индекс начиная с 0)
controller.setLanguage(0)

// Освободить ресурсы (вызывать в viewWillDisappear)
controller.dispose()
```

#### Свойства (только чтение)

```swift
// Проверить играет ли сейчас
let playing = controller.isPlaying

// Получить общую высоту прокрутки
let totalHeight = controller.duration

// Получить текущую позицию
let currentPos = controller.currentPosition
```

#### Обратные вызовы

```swift
// Слушать изменения прокрутки
controller.onScrollChanged = { position in
    // Обновить прогресс-бар
    print("Позиция: \(position)")
}
```

## Puzzle API

### PuzzleViewerController

Контроллер для взаимодействия с пазлом.

```swift
let puzzleController = PuzzleViewerController()

// Загрузить puzzle файл
puzzleController.loadPuzzle(filePath: "/путь/к/puzzle.puzzle") { result in
    switch result {
    case .success:
        puzzleController.selectPiece(0)
    case .failure(let error):
        print("Ошибка: \(error)")
    }
}

// Перейти к кусочку по индексу
puzzleController.selectPiece(5)

// Получить текущий кусочек
let currentPiece = puzzleController.currentPieceIndex

// Получить общее количество кусочков
let totalPieces = puzzleController.totalPieces

// Управление воспроизведением текущего кусочка
puzzleController.play()
puzzleController.pause()

// Переключить превью/звуки для всех кусочков
puzzleController.togglePreview(true)
puzzleController.toggleSounds(false)

// Очистка
puzzleController.dispose()
```

### Обратные вызовы Puzzle

```swift
puzzleController.onPieceSelected = { index in
    print("Выбран кусочек: \(index)")
}
```

## Формат файла

### .comics Файл

Файл .comics - это ZIP архив, содержащий:

- `data.json` - Структура и метаданные комикса
- `layers/` - Изображения слоёв (PNG)
- `sounds/` - Аудио файлы (MP3)

**Пример использования:**

```swift
// Из bundle приложения
let comicsPath = Bundle.main.path(forResource: "episode", ofType: "comics")!

// Из директории документов
let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
let comicsPath = documentsPath.appendingPathComponent("episode.comics").path
```

## Полный пример

```swift
import UIKit
import ComicsViewer

class ComicsPlayerViewController: UIViewController {
    private let scrollView = ImageScrollView()
    private var controller: ComicsViewerController!
    private let playPauseButton = UIButton(type: .system)
    private var isPlaying = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // Настроить scroll view
        view.addSubview(scrollView)
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // Настроить кнопку play/pause
        view.addSubview(playPauseButton)
        playPauseButton.frame = CGRect(x: 0, y: 0, width: 100, height: 44)
        playPauseButton.center = CGPoint(x: view.bounds.midX, y: view.bounds.maxY - 50)
        playPauseButton.setTitle("Пауза", for: .normal)
        playPauseButton.addTarget(self, action: #selector(togglePlayback), for: .touchUpInside)

        // Инициализировать контроллер
        controller = ComicsViewerController(scrollView: scrollView)

        // Настроить слушатель прокрутки
        controller.onScrollChanged = { [weak self] position in
            self?.updateProgressBar(position: position)
        }

        // Загрузить комикс
        let comicsPath = "/путь/к/episode.comics"
        controller.loadComics(filePath: comicsPath) { [weak self] result in
            switch result {
            case .success:
                self?.controller.play()
                self?.isPlaying = true
                self?.playPauseButton.setTitle("Пауза", for: .normal)
            case .failure(let error):
                self?.showError(error: error)
            }
        }
    }

    @objc private func togglePlayback() {
        if isPlaying {
            controller.pause()
            playPauseButton.setTitle("Играть", for: .normal)
        } else {
            controller.play()
            playPauseButton.setTitle("Пауза", for: .normal)
        }
        isPlaying.toggle()
    }

    private func updateProgressBar(position: CGFloat) {
        // Обновить UI
    }

    private func showError(error: Error) {
        // Показать алерт с ошибкой
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        controller.dispose()
    }
}
```

## Требования

- **iOS**: 13.0+
- **macOS**: 10.15+
- **Swift**: 5.9+
- **Frameworks**: Foundation, UIKit/AppKit, AVFoundation

## Bundle ID

```
net.nativemind.comics.viewer
```

## Продвинутое использование

### Прямой доступ к внутренним компонентам

Для продвинутых случаев использования, вы всё ещё можете получить доступ к внутренним компонентам:

```swift
import ComicsViewer

// Низкоуровневый API
let comicsURL = URL(fileURLWithPath: "/путь/к/файлу.comics")
if let comics = ArchiveManager.loadComics(from: comicsURL) {
    scrollView.setComics(comics, from: comicsURL)
    scrollView.languageIndex = 0
    scrollView.soundEnabled = true
}
```

**Примечание:** Использование `ComicsViewerController` рекомендуется для большинства случаев.

## Лицензия

Copyright © 2017-2026 Iron Water Studio, NativeMind. Все права защищены.
