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