# ComfyUI Module

enviroment for comfyui
python 3.12
```
brew install poetry
brew install python@3.12
poetry env use python3.12
poetry install
```

### Setup Pytorch Environment on Mac OS

```bash
poetry run pip install --pre torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/nightly/cpu
```

### Install Dependencies

```bash
poetry run pip install -r comfyui/requirements.txt
```

### Run ComfyUI

```bash
poetry run python comfyui/main.py
```
