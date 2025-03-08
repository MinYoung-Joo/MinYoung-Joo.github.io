#!/bin/bash

# 환경 설정
export PATH="$PATH:/opt/homebrew/bin"

# 설정 - 경로를 실제 환경에 맞게 수정
VAULT_DIR="/Users/myjoo/Library/Mobile Documents/iCloud~md~obsidian/Documents/myjoo"
BLOG_DIR="/Users/myjoo/Documents/blog"
TARGET_DIR="$BLOG_DIR/content/english/blog"
IMAGE_DIR="$BLOG_DIR/assets/images/blog"
PUBLISH_TAG="#publish"

# 스크립트 실행 디렉토리로 이동
cd "$BLOG_DIR"

# 필요한 디렉토리 생성
mkdir -p "$TARGET_DIR"
mkdir -p "$IMAGE_DIR"

echo "선택적 발행 시작: $PUBLISH_TAG 태그가 있는 노트만 발행합니다."

# 1. 현재 발행 중인 모든 파일의 목록 저장
echo "현재 발행된 파일 목록 수집 중..."
TARGET_FILES=$(find "$TARGET_DIR" -type f -name "*.md" | sort)

# 2. #publish 태그가 있는 모든 노트 찾기 - 단어 경계를 사용하여 정확한 태그만 매칭
echo "#publish 태그가 있는 노트 찾는 중..."
PUBLISH_FILES=$(find "$VAULT_DIR" -type f -name "*.md" -exec grep -l "\b$PUBLISH_TAG\b" {} \; | sort)

# 3. TARGET_DIR에 있지만 더 이상 #publish 태그가 없는 파일 찾기
echo "발행 취소할 노트 확인 중..."

# 파일명->slug 매핑 함수 - 한글 문자 범위 추가
get_slug() {
  local filename=$(basename "$1")
  echo "$filename" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9가-힣ㄱ-ㅎㅏ-ㅣ_.-]//g'
}

# 제목->slug 매핑 함수 - 한글 문자 범위 추가
title_to_slug() {
  echo "$1" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9가-힣ㄱ-ㅎㅏ-ㅣ_.-]//g'
}

# 파일에서 제목 추출 함수
get_title() {
  local file="$1"
  local content=$(cat "$file")
  
  # 프론트매터에서 title 찾기
  if [[ $content == ---* ]]; then
    title=$(echo "$content" | grep -m 1 "^title:" | sed 's/^title: *"\(.*\)".*$/\1/')
    
    # title이 없으면 첫 번째 # 헤더 사용
    if [ -z "$title" ]; then
      title=$(echo "$content" | grep -m 1 "^# " | sed 's/^# \(.*\)$/\1/')
    fi
  else
    # 프론트매터 없으면 첫 번째 # 헤더 사용
    title=$(echo "$content" | grep -m 1 "^# " | sed 's/^# \(.*\)$/\1/')
  fi
  
  # 제목이 여전히 없으면 파일명 사용
  if [ -z "$title" ]; then
    title=$(basename "$file" .md)
  fi
  
  echo "$title"
}

# 발행 중인 파일 목록 생성
declare -A published_files
for file in $TARGET_FILES; do
  title=$(get_title "$file")
  slug=$(title_to_slug "$title")
  published_files["$slug"]="$file"
done

# #publish 태그가 있는 노트 목록 생성
declare -A publish_tagged_files
for file in $PUBLISH_FILES; do
  title=$(get_title "$file")
  slug=$(title_to_slug "$title")
  publish_tagged_files["$slug"]="$file"
done

# 발행 취소할 파일 찾기 및 삭제
for slug in "${!published_files[@]}"; do
  if [[ -z "${publish_tagged_files[$slug]}" ]]; then
    target_file="${published_files[$slug]}"
    echo "발행 취소: $(basename "$target_file")"
    rm -f "$target_file"
  fi
done

# 4. 발행 또는 업데이트할 파일 처리
for file in $PUBLISH_FILES; do
  filename=$(basename "$file")
  rel_path=${file#$VAULT_DIR/}
  dir_path=$(dirname "$rel_path")
  title=$(get_title "$file")
  slug=$(title_to_slug "$title")
  
  # 이미 발행되었는지 확인
  if [[ -n "${published_files[$slug]}" ]]; then
    echo "업데이트: $rel_path -> $slug.md"
    action="update"
  else
    echo "새로 발행: $rel_path -> $slug.md"
    action="new"
  fi
  
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
  
  # 파일 저장 - .md 확장자 추가
  output_file="$TARGET_DIR/${slug}.md"
  echo "$final_content" > "$output_file"
  
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
    sed -i '' "s|!\[\[$img\]\]|{{< image src=\"images/blog/$img_name\" >}}|g" "$output_file"
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
        sed -i '' "s|!\\[.*\\]($img)|{{< image src=\"images/blog/$img_name\" caption=\"$img_alt\" >}}|g" "$output_file"
      else
        sed -i '' "s|!\\[.*\\]($img)|{{< image src=\"images/blog/$img_name\" >}}|g" "$output_file"
      fi
    fi
  done
done

echo "발행 작업 완료: $PUBLISH_TAG 태그가 있는 노트를 발행하고, 태그가 제거된 노트는 발행 취소했습니다."

# 변경사항 Git에 커밋 및 푸시
echo "변경사항 Git에 커밋 및 푸시 중..."
git add .
git commit -m "Update blog posts: $(date +'%Y-%m-%d %H:%M:%S')"
git push

echo "완료! GitHub Actions가 사이트를 빌드하고 배포할 것입니다."