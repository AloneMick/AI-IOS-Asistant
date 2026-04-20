# AI iOS Assistant 🤖✨

**Más potente que Apple Intelligence** — Un asistente de IA de última generación para iPhone, construido con SwiftUI. Soporta **OpenAI, Groq, OpenRouter, Together AI** y endpoints personalizados — incluyendo decenas de modelos open-source completamente gratis.

---

## 🚀 Características

| Característica | Descripción |
|---|---|
| 🔀 **Multi-proveedor** | OpenAI, Groq, OpenRouter, Together AI, Custom |
| 🆓 **Modelos gratuitos** | Llama 3.3, Mistral, Gemma, DeepSeek R1, Phi-3 y más sin coste |
| ☁️ **APIs en la nube** | Todo funciona desde iPhone — sin servidores locales |
| 📡 **Streaming en tiempo real** | Respuestas token a token, como ChatGPT |
| 🎙️ **Modo voz full-duplex** | Habla → IA → TTS. Manos libres total. |
| 👁️ **Visión multimodal** | Envía imágenes desde cámara o galería para análisis |
| 📅 **Integración nativa** | Calendar, Reminders y Contacts via EventKit |
| 💾 **Historial persistente** | SwiftData con búsqueda, fijado y organización |
| ⚡ **System prompt configurable** | Dale cualquier personalidad o rol al asistente |
| 🎨 **UI premium** | Glass morphism, animaciones fluidas, estilo Apple |

---

## 📋 Requisitos

- **Xcode 16+** (para SwiftData y `@Observable`)
- **iOS 18.0+** (mínimo)
- **API Key** de uno de los proveedores cloud (Groq y OpenRouter tienen tier gratuito)

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
│   ├── AppSettings.swift          # @Observable — configuración multi-proveedor
│   └── AIProvider.swift           # AIProvider enum + catálogos de modelos por proveedor
│
├── Services/
│   ├── AIService.swift            # Actor — multi-proveedor, streaming SSE, visión multimodal
│   ├── SpeechManager.swift        # @Observable — STT (SFSpeechRecognizer) + TTS (AVSpeechSynthesizer)
│   └── DeviceIntegrationService.swift  # @Observable — Calendar, Reminders, Contacts
│
├── ViewModels/
│   └── ChatViewModel.swift        # @Observable — MVVM orchestrator, estado de chat
│
├── Views/
│   ├── ConversationView.swift     # Vista principal de chat con banner proveedor/modelo
│   ├── MessageBubbleView.swift    # Burbujas de mensaje con código, TTS, copiar
│   ├── VoiceModeView.swift        # Modo manos libres full-screen con waveform animado
│   ├── SettingsView.swift         # Proveedor picker + modelo por proveedor + API key + host
│   ├── HistoryView.swift          # Historial con búsqueda, swipe, fijado
│   └── ImagePickerView.swift      # Wrapper de UIImagePickerController
│
└── Utilities/
    ├── HistoryManager.swift        # CRUD SwiftData para conversaciones
    └── Extensions.swift            # Color, View, String, Date, Haptics, WaveformShape
```

### Patrón: MVVM + Actor Services

```
View ──► ChatViewModel (@Observable) ──► AIService (actor) ──► [AIProvider endpoint]
              │                       └──► SpeechManager (@Observable)
              │                       └──► DeviceIntegrationService (@Observable)
              └──► SwiftData (ModelContext) ──► Conversation / Message (@Model)
```

---

## 🌐 Proveedores soportados

| Proveedor | Modelos destacados | API Key | Coste |
|---|---|---|---|
| **OpenAI** | GPT-4o, GPT-4 Turbo | Sí | Pago |
| **Groq** | Llama 3.3 70B, Mixtral, Gemma | Sí | **Gratis** (tier) |
| **OpenRouter** | 200+ modelos, DeepSeek R1, Llama, Claude | Sí | **Gratis** (muchos) |
| **Together AI** | Llama 3.1 405B, DeepSeek R1, Qwen 2.5 | Sí | **Gratis** (tier) |
| **Custom** | vLLM, Llama.cpp en VPS, etc. | Opcional | Variable |

> **Nota:** Ollama y LM Studio son servidores de escritorio (macOS/Linux/Windows) y no son compatibles con iOS. Para inferencia privada desde iPhone, usa un VPS con vLLM o Llama.cpp server y configúralo como endpoint personalizado.

### Modelos open-source recomendados (gratuitos)

| Modelo | Proveedor | Contexto | Destacado |
|---|---|---|---|
| Llama 3.3 70B | Groq / OpenRouter / Together | 128K | 🏆 Mejor calidad open-source |
| DeepSeek R1 | OpenRouter / Together | 65K | 🧠 Razonamiento superior |
| Mixtral 8x7B | Groq / OpenRouter | 32K | ⚡ MoE, muy rápido |
| Mistral 7B | Groq / OpenRouter | 32K | 🆓 Siempre gratis |
| Phi-3 Mini | OpenRouter | 128K | 🪶 Ultra-ligero |
| Gemma 2 9B | Groq / OpenRouter | 8K | 🔬 Google open-source |

---

## 🔥 Comparativa vs Apple Intelligence

| Capacidad | Apple Intelligence | Este Asistente |
|---|---|---|
| Modelo base | Apple Foundation Model | GPT-4o, Llama 3.3, DeepSeek R1 y más |
| Visión multimodal | Limitada | ✅ Full — cámara + galería |
| Streaming | No | ✅ Token a token |
| Modo voz | Siri | ✅ Full-duplex, manos libres |
| Personalización | Ninguna | ✅ System prompt, temperatura, modelo |
| Historial | No | ✅ SwiftData con búsqueda |
| Integración calendario | Siri Shortcuts | ✅ EventKit nativo |
| Código (bloques) | No | ✅ Syntax highlighting, copiar |
| Multi-modelo | No | ✅ 5 proveedores cloud + Custom endpoint |
| Sin coste | No | ✅ Groq/OpenRouter/Together gratis |
| iOS 18+ | Requiere iPhone compatible | ✅ Diseñado para iOS 18 |

---

## 📄 Licencia

MIT License — Libre para uso personal y comercial.
