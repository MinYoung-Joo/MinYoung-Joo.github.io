---
title: "옵시디언에서 github.io 블로그로 원하는 글만 선택적으로 발행하기"
date: 2025-03-08
draft: false
image: "images/blog/스크린샷 2025-03-08 오후 10.11.36.png"
---



옵시디언(Obsidian)에서 노트를 관리하면서 원하는 글만 골라서 GitHub Pages 블로그에 발행하는 워크플로우를 만들어보겠습니다. 이 가이드는 Hugo와 Hugoplate 테마를 사용한 방법을 중심으로 설명합니다.

{{< image src="images/blog/스크린샷 2025-03-08 오후 10.11.36.png" >}}
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

## 3. 선택적 발행을 위한 스크립트 작성

`/Users/사용자명/Documents/blog/publish.sh` 파일 생성:

```bash
#!/bin/bash

# 설정 - 경로를 실제 환경에 맞게 수정 (따옴표로 경로 처리)
VAULT_DIR="/Users/${user_name}/Library/Mobile Documents/iCloud~md~obsidian/Documents/${vault_name}"
BLOG_DIR="/Users/${user_name}/Documents/blog"
TARGET_DIR="$BLOG_DIR/content/english/blog"
IMAGE_DIR="$BLOG_DIR/assets/images/blog"
PUBLISH_TAG=""

# 디버깅을 위한 경로 확인
echo "VAULT_DIR: $VAULT_DIR"
echo "TARGET_DIR: $TARGET_DIR"

# 스크립트 실행 디렉토리로 이동
cd "$BLOG_DIR" || { echo "블로그 디렉토리 이동 실패"; exit 1; }

# 필요한 디렉토리 생성
mkdir -p "$TARGET_DIR"
mkdir -p "$IMAGE_DIR"

echo "선택적 발행 시작: $PUBLISH_TAG 태그가 있는 노트만 발행합니다."

# 발행된 노트 목록 수집
echo "현재 발행된 파일 목록 수집 중..."
if [ -d "$TARGET_DIR" ]; then
  published_files=$(find "$TARGET_DIR" -type f -name "*.md" 2>/dev/null || echo "")
else
  published_files=""
fi

# PUBLISH_TAG가 있는 노트 찾기 - 특수문자가 있는 파일명도 안전하게 처리
echo " 태그가 있는 노트 찾는 중..."
if [ -d "$VAULT_DIR" ]; then
  # 임시 파일 생성
  temp_file=$(mktemp)
  
  # 모든 마크다운 파일 찾기
  find "$VAULT_DIR" -type f -name "*.md" -print0 | while IFS= read -r -d $'\0' file; do
    # 파일의 처음 3줄만 검사
    if head -n 3 "$file" | grep -q "$PUBLISH_TAG"; then
      echo "$file" >> "$temp_file"
      echo "발행 대상 파일 발견: $(basename "$file")"
    fi
  done
  
  # 결과 파일에서 to_publish_files 값 설정
  to_publish_files=$(cat "$temp_file")
  rm "$temp_file"
else
  echo "옵시디언 볼트 디렉토리를 찾을 수 없습니다: $VAULT_DIR"
  exit 1
fi

# 현재 발행된 파일의 제목 목록 만들기
current_titles=()
for file in $published_files; do
  if [ -f "$file" ]; then
    title=$(grep -m 1 "^title:" "$file" 2>/dev/null | sed 's/^title: *"\(.*\)".*$/\1/' || basename "$file" .md)
    current_titles+=("$title")
  fi
done

# 발행할 파일의 제목 목록 만들기
publish_titles=()
# IFS 변경으로 파일명에 공백이 있는 경우 처리
OLDIFS="$IFS"
IFS=$'\n'
to_publish_array=($to_publish_files)
IFS="$OLDIFS"

for file in "${to_publish_array[@]}"; do
  if [ -f "$file" ]; then
    # 파일명을 우선적으로 제목으로 사용
    filename_without_ext="${file##*/}"
    filename_without_ext="${filename_without_ext%.md}"
    title="$filename_without_ext"
    
    publish_titles+=("$title")
  fi
done

# 발행 취소할 파일 찾기
for file in $published_files; do
  if [ -f "$file" ]; then
    # 파일 이름만 추출
    base_filename=$(basename "$file")
    
    # _index.md 파일만 삭제에서 제외
    if [[ "$base_filename" == "_index.md" ]]; then
      echo "시스템 파일 보존: $base_filename"
      continue
    fi
    
    title=$(grep -m 1 "^title:" "$file" 2>/dev/null | sed 's/^title: *"\(.*\)".*$/\1/' || basename "$file" .md)
    should_unpublish=true
    
    # 이 제목이 publish_titles에 있는지 확인
    for publish_title in "${publish_titles[@]}"; do
      if [ "$title" = "$publish_title" ]; then
        should_unpublish=false
        break
      fi
    done
    
    # 발행 취소
    if [ "$should_unpublish" = true ]; then
      echo "발행 취소: $title"
      rm -f "$file"
    fi
  fi
done

# 발행 또는 업데이트할 노트 처리
for file in "${to_publish_array[@]}"; do
  # 파일 존재 확인
  if [ ! -f "$file" ]; then
    echo "파일을 찾을 수 없습니다: $file"
    continue
  fi
  
  # 노트 정보 추출
  filename=$(basename "$file")
  
  # 제목에서 특수문자 제거
  safe_title=$(echo "$filename" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9가-힣ㄱ-ㅎㅏ-ㅣ_.-]//g')
  output_file="$TARGET_DIR/$safe_title"
  
  # 내용 읽기
  content=$(cat "$file" 2>/dev/null || echo "")
  
  # 파일명을 우선적으로 제목으로 사용
  filename_without_ext="${filename%.md}"
  title="$filename_without_ext"
  
  # 발행 상태 확인
  if [ -f "$output_file" ]; then
    echo "업데이트: $title"
  else
    echo "새로 발행: $title"
  fi
  
  # PUBLISH_TAG 제거
  content=$(echo "$content" | sed "s/$PUBLISH_TAG//g")
  
  # 이미지 처리 - 파일 내용에서 이미지 참조 확인
  image_line=""
  dir=$(dirname "$file")
  
  # 옵시디언 위키 스타일 이미지 찾기 ({{< image src="images/blog/filename.png" >}})
  found_images=()
  while IFS= read -r line; do
    if [[ "$line" == *"![["* ]]; then
      if [[ "$line" == *"]]"* ]]; then
        # 이미지 이름 추출
        img_path=$(echo "$line" | sed -n 's/.*!\[\[\([^]]*\)\]\].*/\1/p')
        if [ -n "$img_path" ]; then
          img_name=$(basename "$img_path")
          found_images+=("$img_name")
          
          # 첫 번째 이미지는 대표 이미지로 설정
          if [ -z "$image_line" ]; then
            # 이미지 라인을 미리 형식화하여 저장 (변수만 포함)
            image_line="image: \"images/blog/$img_name\""
          fi
          
          # 이미지 파일 복사
          if [ -f "$VAULT_DIR/attachments/$img_name" ]; then
            echo "  이미지 복사: attachments/$img_name"
            cp "$VAULT_DIR/attachments/$img_name" "$IMAGE_DIR/$img_name"
          elif [ -f "$dir/$img_name" ]; then
            echo "  이미지 복사: $img_name"
            cp "$dir/$img_name" "$IMAGE_DIR/$img_name"
          fi
        fi
      fi
    fi
  done < "$file"
  
  # 프론트매터 처리
  if [[ $content == ---* ]]; then
    # 프론트매터와 본문 분리
    front_matter=$(echo "$content" | awk 'BEGIN{flag=0} /^---/{flag++; print; next} flag==1{print} flag==2{exit}')
    rest_content=$(echo "$content" | awk 'BEGIN{flag=0} /^---/{flag++} flag==2{print}' | tail -n +2)
    
    # draft: false 추가 (없는 경우)
    if ! grep -q "^draft:" <<<"$front_matter"; then
      front_matter=$(echo "$front_matter" | sed '/^---$/a draft: false')
    fi
    
    # title 확인 및 추가 (없는 경우)
    if ! grep -q "^title:" <<<"$front_matter"; then
      front_matter=$(echo "$front_matter" | sed '/^---$/a title: \"'\"$title\"'\"')
    else
      # 기존 title 값을 새로 찾은 title로 업데이트
      front_matter=$(echo "$front_matter" | sed 's/^title:.*$/title: \"'\"$title\"'\"/')
    fi
    
    # image 필드 처리
    if [ -n "$image_line" ]; then
      # 이미지 필드가 이미 있는지 확인
      if grep -q "^image:" <<<"$front_matter"; then
        # 이미지 필드 교체 (sed 대신 awk 사용)
        new_front_matter=""
        while IFS= read -r line; do
          if [[ "$line" == "image:"* ]]; then
            echo "$image_line" >> /tmp/front_matter.tmp
          else
            echo "$line" >> /tmp/front_matter.tmp
          fi
        done <<< "$front_matter"
        front_matter=$(cat /tmp/front_matter.tmp)
        rm /tmp/front_matter.tmp
      else
        # 이미지 필드 추가 - 안전한 방식으로
        echo "$front_matter" | sed '/^---$/a '"$image_line" > /tmp/front_matter.tmp
        front_matter=$(cat /tmp/front_matter.tmp)
        rm /tmp/front_matter.tmp
      fi
    else
      # 이미지가 없는 경우 이미지 필드 제거
      if grep -q "^image:" <<<"$front_matter"; then
        new_front_matter=""
        while IFS= read -r line; do
          if [[ "$line" != "image:"* ]]; then
            echo "$line" >> /tmp/front_matter.tmp
          fi
        done <<< "$front_matter"
        front_matter=$(cat /tmp/front_matter.tmp)
        rm /tmp/front_matter.tmp
      fi
    fi
    
    # 최종 내용 조합
    final_content="${front_matter}${rest_content}"
  else
    # 프론트매터가 없는 경우
    # 첫 번째 줄이 # 으로 시작하면 본문에서 제외
    if [[ $content == \#* ]]; then
      content_without_title=$(echo "$content" | tail -n +2)
    else
      content_without_title="$content"
    fi
    
    # 프론트매터 추가
    date=$(date +"%Y-%m-%d")
    if [ -n "$image_line" ]; then
      final_content="---\ntitle: \"$title\"\ndate: $date\ndraft: false\n$image_line\n---\n\n$content_without_title"
    else
      final_content="---\ntitle: \"$title\"\ndate: $date\ndraft: false\n---\n\n$content_without_title"
    fi
  fi
  
  # 이미지 태그 변환 준비
  temp_content="$final_content"
  
  # 이미지 태그 변환 실행 - 모든 옵시디언 위키 링크를 Hugo 이미지 태그로 변환
  for img_name in "${found_images[@]}"; do
    temp_content=$(echo "$temp_content" | sed "s|!\\[\\[$img_name\\]\\]|{{< image src=\"images/blog/$img_name\" >}}|g")
  done
  
  # 최종 내용 저장
  echo "$temp_content" > "$output_file"
done

echo "발행 작업 완료: $PUBLISH_TAG 태그가 있는 노트를 발행하고, 태그가 제거된 노트는 발행 취소했습니다."

# 변경사항 Git에 커밋 및 푸시
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
2. 발행하려는 노트에 `` 태그 추가:
   ```markdown
   # 발행할 노트 제목
   
   
   
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

이 방법을 통해 옵시디언에서 작성한 노트 중 원하는 것만 선택적으로 Hugo 블로그로 발행할 수 있습니다. `` 태그만 추가하고 단축키 한 번으로 발행 과정이 자동화되어 편리하게 블로그를 관리할 수 있습니다.

### 참고
* https://themes.gohugo.io/themes/hugoplate/
* https://gohugo.io/getting-started/usage/
* https://themes.gohugo.io/themes/hugoplate/
