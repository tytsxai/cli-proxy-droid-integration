# CLI Proxy API 통합 도구 - Factory CLI (Droid)

> 로컬 프록시 서버를 통해 Factory CLI (Droid)에서 타사 AI 모델 사용

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-blue)]()

[English](README.md) | [中文](README_zh-CN.md) | **한국어**

---

## 이것은 무엇인가요?

이 도구는 **Factory CLI (Droid)**를 타사 AI 모델 제공업체에 연결합니다:

1. **자격 증명 자동 감지** - 여러 소스에서 자동 읽기
2. **사용자 정의 모델 구성** - Factory CLI에서 사용
3. **로컬 프록시 실행** - OpenAI 호환 API 엔드포인트 제공

### 아키텍처

```
┌─────────────────┐     ┌─────────────────────┐     ┌──────────────────┐
│  Factory CLI    │────▶│  로컬 프록시        │────▶│  타사 AI         │
│  (Droid)        │     │  (localhost:8317)   │     │  제공업체        │
└─────────────────┘     └─────────────────────┘     └──────────────────┘
```

---

## 사전 요구 사항

- [ ] **Factory CLI (Droid)** 설치됨
- [ ] 타사 제공업체의 **API 자격 증명**
- [ ] **macOS 또는 Linux**
- [ ] 기본 터미널 지식

---

## 설치 (단계별)

### 1단계: 저장소 복제

```bash
cd ~/Desktop
git clone https://github.com/tytsxai/cli-proxy-droid-integration.git
cd cli-proxy-droid-integration
```

### 2단계: 구성 파일 생성

```bash
cp CLIProxyAPI/config.yaml.example CLIProxyAPI/config.yaml
```

### 3단계: 구성 파일 편집

```bash
nano CLIProxyAPI/config.yaml
```

`codex-api-key` 섹션 수정:

```yaml
codex-api-key:
  - api-key: "실제_API_키"
    prefix: "provider"
    base-url: "https://API_엔드포인트/api"
```

### 4단계: 설정 스크립트 실행

```bash
chmod +x setup.sh
./setup.sh
```

### 5단계: 설치 확인

```bash
./verify-integration.sh
```

---

## 사용법

```bash
droid
```

1. `/model` 입력하여 모델 목록 보기
2. 사용자 정의 모델 선택
3. 대화 시작!

---

## 문제 해결

### 포트 8317 사용 중

```bash
lsof -i :8317
kill <PID>
./setup.sh
```

### 도움이 필요하세요? AI에게 물어보세요!

1. 이 README 파일 복사
2. ChatGPT, Claude 등에 붙여넣기
3. 문제 설명

AI가 프로젝트를 이해하고 도와줍니다.

---

## 감사의 말

- **[CLIProxyAPI](https://github.com/anthropics/cli-proxy-api)** - 핵심 프록시 서버
- **[Factory CLI (Droid)](https://github.com/openai/codex)** - 통합 CLI 도구

---

## 라이선스

MIT License - [LICENSE](LICENSE) 참조
