# AI iOS Assistant 🤖✨

**Más potente que Apple Intelligence** — Un asistente de IA de última generación para iOS, construido con SwiftUI, GPT-4o y capacidades multimodales completas.

---

## 🚀 Características

| Característica | Descripción |
|---|---|
| 🧠 **GPT-4o / GPT-4 Turbo** | Motor de IA de última generación con 128k tokens de contexto |
| 📡 **Streaming en tiempo real** | Respuestas token a token, como ChatGPT |
| 🎙️ **Modo voz full-duplex** | Habla → IA → TTS. Manos libres total. |
| 👁️ **Visión multimodal** | Envía imágenes desde cámara o galería para análisis |
| 📅 **Integración nativa** | Calendar, Reminders y Contacts via EventKit |
| 💾 **Historial persistente** | SwiftData con búsqueda, fijado y organización |
| ⚡ **System prompt configurable** | Dale cualquier personalidad o rol al asistente |
| 🎨 **UI premium** | Glass morphism, animaciones fluidas, estilo Apple |
| 🔒 **Privacidad** | API Key almacenada solo en UserDefaults local |

---

## 📋 Requisitos

- **Xcode 15+** (para SwiftData y `@Observable`)
- **iOS 17.0+** (mínimo)
- **API Key de OpenAI** → [platform.openai.com](https://platform.openai.com/api-keys)

---

## 🛠️ Setup en Xcode

### 1. Crear el proyecto

1. Abre Xcode → **File > New > Project**
2. Selecciona **App** (iOS)
3. Configura:
   - **Product Name:** `AIAssistant`
   - **Bundle Identifier:** `com.tuempresa.aiassistant`
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Storage:** SwiftData ✓
4. Guarda el proyecto

### 2. Añadir los archivos fuente

Arrastra la carpeta `AIAssistant/` completa a tu proyecto en Xcode:
- Marca **"Copy items if needed"** ✓
- Marca **"Add to target: AIAssistant"** ✓

### 3. Reemplazar el App entry point

En `AIAssistantApp.swift` del proyecto base, reemplaza con el de este repositorio (el `@main` ya está configurado).

### 4. Configurar permisos (Info.plist)

Los permisos ya están en `AIAssistant/App/Info.plist`. Asegúrate de que tu target use ese plist, o añade estas claves al tuyo:

```xml
<key>NSCameraUsageDescription</key>
<string>Para enviar imágenes al asistente de IA</string>
<key>NSMicrophoneUsageDescription</key>
<string>Para el reconocimiento de voz</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Para hablarle al asistente de IA</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Para compartir fotos con el asistente</string>
<key>NSCalendarsFullAccessUsageDescription</key>
<string>Para consultar y crear eventos de calendario</string>
<key>NSRemindersFullAccessUsageDescription</key>
<string>Para consultar y crear recordatorios</string>
<key>NSContactsUsageDescription</key>
<string>Para buscar contactos</string>
```

### 5. Añadir tu API Key

1. Abre la app en el simulador o dispositivo
2. Ve a la pestaña **Ajustes ⚙️**
3. Introduce tu API Key de OpenAI (`sk-...`)
4. Selecciona el modelo (GPT-4o recomendado)
5. Toca **Probar conexión** ✓

---

## 🏗️ Arquitectura

```
AIAssistant/
├── App/
│   ├── AIAssistantApp.swift       # @main, SwiftData container, servicios
│   ├── ContentView.swift          # TabView raíz (Chat / Historial / Ajustes)
│   └── Info.plist                 # Permisos del sistema
│
├── Models/
│   ├── Message.swift              # @Model SwiftData — mensajes con rol, contenido, imagen
│   ├── Conversation.swift         # @Model SwiftData — conversaciones con mensajes
│   └── AppSettings.swift          # @Observable — configuración con UserDefaults
│
├── Services/
│   ├── AIService.swift            # Actor — OpenAI API, streaming SSE, visión multimodal
│   ├── SpeechManager.swift        # @Observable — STT (SFSpeechRecognizer) + TTS (AVSpeechSynthesizer)
│   └── DeviceIntegrationService.swift  # @Observable — Calendar, Reminders, Contacts
│
├── ViewModels/
│   └── ChatViewModel.swift        # @Observable — MVVM orchestrator, estado de chat
│
├── Views/
│   ├── ConversationView.swift     # Vista principal de chat con streaming, imágenes, barra de entrada
│   ├── MessageBubbleView.swift    # Burbujas de mensaje con código, TTS, copiar
│   ├── VoiceModeView.swift        # Modo manos libres full-screen con waveform animado
│   ├── SettingsView.swift         # Ajustes completos: modelo, temperatura, voz, system prompt
│   ├── HistoryView.swift          # Historial con búsqueda, swipe, fijado
│   └── ImagePickerView.swift      # Wrapper de UIImagePickerController
│
└── Utilities/
    ├── HistoryManager.swift        # CRUD SwiftData para conversaciones
    └── Extensions.swift            # Color, View, String, Date, Haptics, WaveformShape
```

### Patrón: MVVM + Actor Services

```
View ──► ChatViewModel (@Observable) ──► AIService (actor)
              │                       └──► SpeechManager (@Observable)
              │                       └──► DeviceIntegrationService (@Observable)
              └──► SwiftData (ModelContext) ──► Conversation / Message (@Model)
```

---

## 🔥 Comparativa vs Apple Intelligence

| Capacidad | Apple Intelligence | Este Asistente |
|---|---|---|
| Modelo base | Apple Foundation Model | GPT-4o (128k ctx) |
| Visión multimodal | Limitada | ✅ Full — cámara + galería |
| Streaming | No | ✅ Token a token |
| Modo voz | Siri | ✅ Full-duplex, manos libres |
| Personalización | Ninguna | ✅ System prompt, temperatura, modelo |
| Historial | No | ✅ SwiftData con búsqueda |
| Integración calendario | Siri Shortcuts | ✅ EventKit nativo |
| Código (bloques) | No | ✅ Syntax highlighting, copiar |
| Multi-modelo | No | ✅ GPT-4o, GPT-4T, GPT-3.5 |

---

## 📄 Licencia

MIT License — Libre para uso personal y comercial.
