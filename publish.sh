#!/bin/bash

# 환경 설정
export PATH="$PATH:/opt/homebrew/bin"

# 설정 - 경로를 실제 환경에 맞게 수정
VAULT_DIR="/Users/myjoo/Library/Mobile Documents/iCloud~md~obsidian/Documents/myjoo"
BLOG_DIR="/Users/myjoo/Documents/blog"
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

# 기존 파일 목록 저장 (중복 발행 방지용)
previously_published_files=$(find "$TARGET_DIR" -type f -name "*.md" | xargs -n1 basename)

# 태그가 있는 파일 찾기 - grep 명령 개선
find "$VAULT_DIR" -type f -name "*.md" -exec grep -l "\b$PUBLISH_TAG\b" {} \; | while read file; do
  filename=$(basename "$file")
  rel_path=${file#$VAULT_DIR/}
  dir_path=$(dirname "$rel_path")
  
  # URL 친화적인 파일명 생성 (한글 유지)
  # 공백을 하이픈으로 변경하고 특수 문자만 제거
  slug=$(echo "$filename" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9가-힣ㄱ-ㅎㅏ-ㅣ_.-]//g')
  
  # 이미 발행된 파일인지 확인 (중복 발행 방지)
  if echo "$previously_published_files" | grep -q "^$slug$"; then
    echo "이미 발행된 노트 건너뛰기: $rel_path"
    continue
  fi
  
  echo "발행: $rel_path -> $slug"
  
  # 파일 내용 읽기
  content=$(cat "$file")
  
  # PUBLISH_TAG 제거 (내용에서 태그 자체를 삭제)
  content=$(echo "$content" | sed "s/$PUBLISH_TAG//g")
  
  # 프론트매터 처리
  if [[ $content == ---* ]]; then
    # 프론트매터 추출
    front_matter=$(echo "$content" | awk '/^---/{i++}i==1{print}i==2{exit}')
    rest_content=$(echo "$content" | awk '/^---/{i++}i>1{print}' | tail -n +2)
    
    # draft: false 추가 (없는 경우)
    if ! echo "$front_matter" | grep -q "draft:"; then
      front_matter=$(echo "$front_matter" | sed '/^---$/i\\
draft: false')
    fi
    
    # image 필드 확인 (이미지가 있는 경우 추가)
    if ! echo "$front_matter" | grep -q "image:"; then
      # 첫 번째 이미지 찾기
      first_image=$(grep -o -m 1 "!\[\[.*\]\]" "$file" | sed 's/!\[\[\(.*\)\]\]/\1/g')
      if [ -n "$first_image" ]; then
        img_name=$(basename "$first_image")
        front_matter=$(echo "$front_matter" | sed '/^---$/i\\
image: "images/blog/'"$img_name"'"')
      fi
    fi
    
    # 최종 내용 조합
    final_content="${front_matter}${rest_content}"
  else
    # 프론트매터가 없는 경우 추가
    # 첫 번째 줄이 # 으로 시작하면 제목으로 사용
    if [[ $content == \#* ]]; then
      title=$(echo "$content" | head -n 1 | sed 's/^# //')
      content_without_title=$(echo "$content" | tail -n +2)
    else
      title=$(basename "$file" .md)
      content_without_title="$content"
    fi
    
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

$content_without_title"
  fi
  
  # 파일 저장
  echo "$final_content" > "$TARGET_DIR/$slug"
  
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
    
    # 이미지 경로 업데이트 - Hugo 방식으로 (macOS sed 호환성 수정)
    sed -i '' "s|!\[\[$img\]\]|{{< image src=\"images/blog/$img_name\" >}}|g" "$TARGET_DIR/$slug"
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
      
      # 이미지 경로 업데이트 - Hugo 방식으로 (macOS sed 호환성 수정)
      if [ -n "$img_alt" ] && [ "$img_alt" != " " ]; then
        sed -i '' "s|!\\[.*\\]($img)|{{< image src=\"images/blog/$img_name\" caption=\"$img_alt\" >}}|g" "$TARGET_DIR/$slug"
      else
        sed -i '' "s|!\\[.*\\]($img)|{{< image src=\"images/blog/$img_name\" >}}|g" "$TARGET_DIR/$slug"
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