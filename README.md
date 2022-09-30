### SDVoicePlayer
一个播放语音的播放器。

### 功能

1. 子线程播放，不阻塞主线程，线程安全。
2. 自动下载和缓存。
3. block回调，使用方便。

### 使用

播放：

```
SDVoicePlayer.shared.play(voice: voice.voiceURL, playTimeChanged: playTimeChangedBlock, playCompletion: playCompletionBlock)
```

停止：

```
SDVoicePlayer.shared.stop()
```

详见Example工程。
