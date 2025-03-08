---
title: "옵시디언에서 GitHub Pages로 선택적 발행하기: Hugo와 Shell Commands를 활용한 방법"
date: 2025-03-08
draft: false
image: "images/blog/ "
---

# 옵시디언에서 GitHub Pages로 선택적 발행하기: Hugo와 Shell Commands를 활용한 방법

옵시디언에서 모든 노트를 관리하면서 원하는 글만 GitHub Pages 블로그에 발행하는 워크플로우를 만들어보겠습니다. 이 가이드는 Hugo와 Hugoplate 테마를 사용한 방법을 중심으로 설명합니다.

## 목차

1. [준비물 및 환경설정](#1-준비물-및-환경설정)
2. [Hugo 블로그 설정](#2-hugo-블로그-설정)
3. [선택적 발행을 위한 스크립트 작성](#3-선택적-발행을-위한-스크립트-작성)
4. [옵시디언 Shell Commands 플러그인 설정](#4-옵시디언-shell-commands-플러그인-설정)
5. [사용 방법](#5-사용-방법)
6. [문제 해결](#6-문제-해결)

## 1. 준비물 및 환경설정

필요한 도구:
- [옵시디언](https://obsidian.md/) (노트 작성용)
- [Git](https://git-scm.com/) (버전 관리 및 배포)
- [Hugo](https://gohugo.io/) (정적 사이트 생성기)
- [GitHub 계정](https://github.com/) (블로그 호스팅)

### 폴더 구조
```
/Users/사용자명/
├── Library/Mobile Documents/iCloud~md~obsidian/Documents/
│   └── 볼트이름/             # 옵시디언 볼트 (모든 노트 관리)
│       ├── Personal/
│       ├── Work/
│       └── 기타 폴더/
└── Documents/
    └── blog/                # Hugo 블로그 (GitHub과 연결됨)
```

## 2. Hugo 블로그 설정

### 2.1 Hugoplate 테마로 새 사이트 생성

```bash
# 블로그 디렉토리 생성
mkdir -p ~/Documents/blog
cd ~/Documents/blog

# Hugoplate 테마 클론
git clone https://github.com/zeon-studio/hugoplate.git .

# Git 정보 초기화
rm -rf .git
git init
git add .
git commit -m "Initial commit with Hugoplate theme"
```

### 2.2 GitHub 연결 및 설정

```bash
# GitHub 저장소 생성 후 연결
git remote add origin git@github.com:사용자명/사용자명.github.io.git
git push -u origin main
```

GitHub Pages 설정:
1. GitHub 저장소로 이동 > Settings > Pages
2. Source: "GitHub Actions"로 설정

### 2.3 GitHub Actions 설정

`.github/workflows/hugo.yml` 파일 생성:

```yaml
name: Deploy Hugo site

on:
  push:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: true
          
      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v2
        with:
          hugo-version: 'latest'
          extended: true
          
      - name: Build
        run: hugo --minify
        
      - name: Deploy
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./public
```

## 3. 선택적 발행을 위한 스크립트 작성

`/Users/사용자명/Documents/blog/publish.sh` 파일 생성:

```bash
#!/bin/bash

# 환경 설정
export PATH="$PATH:/opt/homebrew/bin"

# 설정 - 경로를 실제 환경에 맞게 수정
VAULT_DIR="/Users/사용자명/Library/Mobile Documents/iCloud~md~obsidian/Documents/볼트이름"
BLOG_DIR="/Users/사용자명/Documents/blog"
TARGET_DIR="$BLOG_DIR/content/english/blog"
IMAGE_DIR="$BLOG_DIR/assets/images/blog"
PUBLISH_TAG="#publish"
HUGO_PATH="/opt/homebrew/bin/hugo" # 절대 경로 사용

# 스크립트 실행 디렉토리로 이동
cd "$BLOG_DIR"

# 필요한 디렉토리 생성
mkdir -p "$TARGET_DIR"
mkdir -p "$IMAGE_DIR"

echo "선택적 발행 시작: $PUBLISH_TAG 태그가 있는 노트만 발행합니다."

# 태그가 있는 파일 찾기
find "$VAULT_DIR" -type f -name "*.md" -exec grep -l "$PUBLISH_TAG" {} \; | while read file; do
  filename=$(basename "$file")
  rel_path=${file#$VAULT_DIR/}
  dir_path=$(dirname "$rel_path")
  
  # 파일명에서 공백 및 특수문자 처리 (Hugo 친화적으로)
  clean_filename=$(echo "$filename" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9-_.]/-/g' | tr '[:upper:]' '[:lower:]')
  
  echo "발행: $rel_path -> $clean_filename"
  
  # 파일 내용 읽기
  content=$(cat "$file")
  
  # 프론트매터 처리
  if [[ $content == ---* ]]; then
    # 프론트매터에서 태그 줄 찾기
    front_matter=$(echo "$content" | awk '/^---/{i++}i==1{print}i==2{exit}')
    rest_content=$(echo "$content" | awk '/^---/{i++}i>1{print}' | tail -n +2)
    
    # #publish 태그 제거
    cleaned_content=$(echo "$front_matter" | sed "s/$PUBLISH_TAG//g")
    
    # draft: false 추가 (없는 경우)
    if ! echo "$cleaned_content" | grep -q "draft:"; then
      cleaned_content=$(echo "$cleaned_content" | sed '/^---$/i draft: false')
    fi
    
    # image 필드 확인 (이미지가 있는 경우 추가)
    if ! echo "$cleaned_content" | grep -q "image:"; then
      # 첫 번째 이미지 찾기
      first_image=$(grep -o -m 1 "!\[\[.*\]\]" "$file" | sed 's/!\[\[\(.*\)\]\]/\1/g')
      if [ -n "$first_image" ]; then
        img_name=$(basename "$first_image")
        cleaned_content=$(echo "$cleaned_content" | sed "/^---$/i image: \"images/blog/$img_name\"")
      fi
    fi
    
    # 최종 내용 조합
    final_content="${cleaned_content}${rest_content}"
  else
    # 프론트매터가 없는 경우 추가
    title=$(head -n 1 "$file" | sed 's/^# //')
    date=$(date +"%Y-%m-%d")
    
    # 첫 번째 이미지 찾기
    first_image=$(grep -o -m 1 "!\[\[.*\]\]" "$file" | sed 's/!\[\[\(.*\)\]\]/\1/g')
    image_line=""
    if [ -n "$first_image" ]; then
      img_name=$(basename "$first_image")
      image_line="image: \"images/blog/$img_name\""
    fi
    
    final_content="---
title: \"$title\"
date: $date
draft: false
$image_line
---

$content"
  fi
  
  # 파일 저장
  echo "$final_content" > "$TARGET_DIR/$clean_filename"
  
  # 이미지 처리
  dir=$(dirname "$file")
  
  # 첨부 파일 처리 - 옵시디언 Wiki 링크 스타일 (![[ ]])
  grep -o "!\[\[.*\]\]" "$file" | sed 's/!\[\[\(.*\)\]\]/\1/g' | while read img; do
    img_name=$(basename "$img")
    
    # 이미지 파일 찾기 및 복사
    if [ -f "$dir/$img" ]; then
      echo "  이미지 복사: $img"
      cp "$dir/$img" "$IMAGE_DIR/$img_name"
    elif [ -f "$VAULT_DIR/attachments/$img" ]; then
      echo "  이미지 복사: attachments/$img"
      cp "$VAULT_DIR/attachments/$img" "$IMAGE_DIR/$img_name"
    fi
    
    # 이미지 경로 업데이트 - Hugo 방식으로
    sed -i "s|!\[\[$img\]\]|{{< image src=\"images/blog/$img_name\" >}}|g" "$TARGET_DIR/$clean_filename"
  done
  
  # Markdown 이미지 링크 스타일 (![]())
  grep -o "!\[.*\](.*)" "$file" | sed 's/!\[.*\](\(.*\))/\1/g' | while read img; do
    # 상대 경로 처리
    img_path="$img"
    if [[ "$img" != /* && "$img" != http* ]]; then
      img_path="$dir/$img"
    fi
    
    if [[ "$img" != http* && -f "$img_path" ]]; then
      img_name=$(basename "$img")
      echo "  이미지 복사: $img_name"
      cp "$img_path" "$IMAGE_DIR/$img_name"
      
      # 이미지 설명 추출
      img_alt=$(grep -o "!\[.*\]($img)" "$file" | sed 's/!\[\(.*\)\](.*)$/\1/g')
      
      # 이미지 경로 업데이트 - Hugo 방식으로
      if [ -n "$img_alt" ] && [ "$img_alt" != " " ]; then
        sed -i "s|!\\[.*\\]($img)|{{< image src=\"images/blog/$img_name\" caption=\"$img_alt\" >}}|g" "$TARGET_DIR/$clean_filename"
      else
        sed -i "s|!\\[.*\\]($img)|{{< image src=\"images/blog/$img_name\" >}}|g" "$TARGET_DIR/$clean_filename"
      fi
    fi
  done
done

echo "발행 완료: $PUBLISH_TAG 태그가 있는 노트가 Hugo 블로그에 발행되었습니다."

# Hugo 사이트 빌드 - 절대 경로 사용
echo "Hugo 사이트 빌드 중..."
$HUGO_PATH --minify

echo "변경사항 Git에 커밋 및 푸시 중..."
git add .
git commit -m "Update blog posts: $(date +'%Y-%m-%d %H:%M:%S')"
git push

echo "완료! GitHub Actions가 사이트를 빌드하고 배포할 것입니다."
```

스크립트에 실행 권한 부여:
```bash
chmod +x ~/Documents/blog/publish.sh
```

## 4. 옵시디언 Shell Commands 플러그인 설정

### 4.1 플러그인 설치

1. 옵시디언 > 설정 > 커뮤니티 플러그인 > 커뮤니티 플러그인 찾아보기
2. "Shell commands" 검색 및 설치
3. 설치 후 활성화

### 4.2 명령어 설정

1. 옵시디언 > 설정 > Shell commands
2. "New shell command" 버튼 클릭
3. 다음과 같이 설정:
   - **명령어 이름**: "Hugo로 발행하기"
   - **쉘 명령어**: `/Users/사용자명/Documents/blog/publish.sh`
   - **작업 디렉토리**: `/Users/사용자명/Documents/blog`

### 4.3 단축키 설정

1. 옵시디언 > 설정 > 단축키
2. "shell"이나 "Hugo로 발행하기" 검색
3. "+" 버튼 클릭하여 원하는 단축키 지정 (예: `Ctrl+Alt+P` 또는 `Cmd+Alt+P`)

## 5. 사용 방법

### 5.1 노트 작성 및 태그 추가

1. 옵시디언에서 평소처럼 노트 작성
2. 발행하려는 노트에 `#publish` 태그 추가:
   ```markdown
   # 발행할 노트 제목
   
   #publish
   
   노트 내용...
   ```

### 5.2 발행하기

1. 발행하려는 노트를 열거나 또는 아무 곳에서나
2. 설정한 단축키(`Ctrl+Alt+P` 또는 `Cmd+Alt+P`)를 눌러 스크립트 실행
3. 잠시 후 `https://사용자명.github.io`에서 발행된 내용 확인

### 5.3 프론트매터 활용

더 세밀한 제어를 위해 프론트매터 사용:

```markdown
---
title: "블로그 포스트 제목"
date: 2024-03-08
tags: [publish, 기술, 튜토리얼]
draft: false
---

# 블로그 포스트 제목

내용...
```

## 6. 문제 해결

### 6.1 경로 문제

스크립트에서 모든 경로가 실제 환경에 맞게 수정되었는지 확인합니다:
- `VAULT_DIR`: 옵시디언 볼트 경로
- `BLOG_DIR`: Hugo 블로그 경로
- `HUGO_PATH`: Hugo 실행 파일 경로

### 6.2 권한 문제

스크립트 실행 권한이 부여되었는지 확인:
```bash
chmod +x ~/Documents/blog/publish.sh
```

### 6.3 Hugo 명령어 문제

Hugo가 PATH에 없다면 절대 경로 사용:
```bash
which hugo  # Hugo 경로 확인
```

### 6.4 이미지 경로 문제

이미지가 제대로 표시되지 않는 경우 Hugo 테마의 이미지 처리 방식 확인:
1. `config.toml` 파일에서 이미지 관련 설정 확인
2. 테마 문서 참고

---

이 방법을 통해 옵시디언에서 작성한 노트 중 원하는 것만 선택적으로 Hugo 블로그로 발행할 수 있습니다. `#publish` 태그만 추가하고 단축키 한 번으로 발행 과정이 자동화되어 편리하게 블로그를 관리할 수 있습니다.
