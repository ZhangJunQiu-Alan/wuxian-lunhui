---
language:
- en
tags:
- audio
- automatic-speech-recognition
- hf-asr-leaderboard
- mlx
- speech-to-text
- speech-to-speech
- speech
- speech generation
- stt
widget:
- example_title: Librispeech sample 1
  src: https://cdn-media.huggingface.co/speech_samples/sample1.flac
- example_title: Librispeech sample 2
  src: https://cdn-media.huggingface.co/speech_samples/sample2.flac
pipeline_tag: automatic-speech-recognition
license: apache-2.0
model_name: whisper-base.en
library_name: mlx-audio
---

# mlx-community/whisper-base.en-asr-6bit
This model was converted to MLX format from [`openai/whisper-base.en`](https://huggingface.co/openai/whisper-base.en) using mlx-audio version **0.2.10**.
Refer to the [original model card](https://huggingface.co/openai/whisper-base.en) for more details on the model.

## Use with mlx-audio

```bash
pip install -U mlx-audio
```

### CLI Example:
```bash
python -m mlx_audio.stt.generate --model mlx-community/whisper-base.en-asr-6bit --audio "audio.wav"
```
### Python Example:
```python
from mlx_audio.stt.utils import load_model
from mlx_audio.stt.generate import generate_transcription
model = load_model("mlx-community/whisper-base.en-asr-6bit")
transcription = generate_transcription(
    model=model,
    audio_path="path_to_audio.wav",
    output_path="path_to_output.txt",
    format="txt",
    verbose=True,
)
print(transcription.text)
```
