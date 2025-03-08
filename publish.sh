#!/bin/bash

# 환경 설정 (Environment setup)
export PATH="$PATH:/opt/homebrew/bin"

# 설정 - 경로를 실제 환경에 맞게 수정 (Configuration - adjust paths as needed)
VAULT_DIR="/Users/myjoo/Library/Mobile Documents/iCloud~md~obsidian/Documents/myjoo"
BLOG_DIR="/Users/myjoo/Documents/blog"
TARGET_DIR="$BLOG_DIR/content/english/blog"
IMAGE_DIR="$BLOG_DIR/assets/images/blog"
PUBLISH_TAG="#publish"

# 디버깅을 위한 경로 확인 (Debug: Print paths)
echo "VAULT_DIR: $VAULT_DIR"
echo "TARGET_DIR: $TARGET_DIR"

# 스크립트 실행 디렉토리로 이동 (Change to blog directory)
cd "$BLOG_DIR" || { echo "블로그 디렉토리 이동 실패"; exit 1; }

# 필요한 디렉토리 생성 (Create required directories)
mkdir -p "$TARGET_DIR"
mkdir -p "$IMAGE_DIR"

echo "선택적 발행 시작: $PUBLISH_TAG 태그가 있는 노트만 발행합니다."

# 발행된 노트 목록 수집 (Collect published files)
echo "현재 발행된 파일 목록 수집 중..."
if [ -d "$TARGET_DIR" ]; then
  published_files=$(find "$TARGET_DIR" -type f -name "*.md" 2>/dev/null || echo "")
else
  published_files=""
fi

# PUBLISH_TAG가 있는 노트 찾기 (Find notes with #publish tag)
echo "#publish 태그가 있는 노트 찾는 중..."
if [ -d "$VAULT_DIR" ]; then
  temp_file=$(mktemp)
  find "$VAULT_DIR" -type f -name "*.md" -print0 | while IFS= read -r -d $'\0' file; do
    if head -n 3 "$file" | grep -q "$PUBLISH_TAG"; then
      echo "$file" >> "$temp_file"
      echo "발행 대상 파일 발견: $(basename "$file")"
    fi
  done
  to_publish_files=$(cat "$temp_file")
  rm "$temp_file"
else
  echo "옵시디언 볼트 디렉토리를 찾을 수 없습니다: $VAULT_DIR"
  exit 1
fi

# 현재 발행된 파일의 제목 목록 만들기 (Create list of current titles)
current_titles=()
for file in $published_files; do
  if [ -f "$file" ]; then
    title=$(grep -m 1 "^title:" "$file" 2>/dev/null | sed 's/^title: *"\(.*\)".*$/\1/' || basename "$file" .md)
    current_titles+=("$title")
  fi
done

# 발행할 파일의 제목 목록 만들기 (List titles to publish)
publish_titles=()
OLDIFS="$IFS"
IFS=$'\n'
to_publish_array=($to_publish_files)
IFS="$OLDIFS"

for file in "${to_publish_array[@]}"; do
  if [ -f "$file" ]; then
    filename_without_ext="${file##*/}"
    filename_without_ext="${filename_without_ext%.md}"
    title="$filename_without_ext"
    publish_titles+=("$title")
  fi
done

# 발행 취소할 파일 찾기 (Find files to unpublish)
for file in $published_files; do
  if [ -f "$file" ]; then
    base_filename=$(basename "$file")
    if [[ "$base_filename" == "_index.md" ]]; then
      echo "시스템 파일 보존: $base_filename"
      continue
    fi
    title=$(grep -m 1 "^title:" "$file" 2>/dev/null | sed 's/^title: *"\(.*\)".*$/\1/' || basename "$file" .md)
    should_unpublish=true
    for publish_title in "${publish_titles[@]}"; do
      if [ "$title" = "$publish_title" ]; then
        should_unpublish=false
        break
      fi
    done
    if [ "$should_unpublish" = true ]; then
      echo "발행 취소: $title"
      rm -f "$file"
    fi
  fi
done

# 발행 또는 업데이트할 노트 처리 (Process notes to publish/update)
for file in "${to_publish_array[@]}"; do
  if [ ! -f "$file" ]; then
    echo "파일을 찾을 수 없습니다: $file"
    continue
  fi
  
  filename=$(basename "$file")
  safe_title=$(echo "$filename" | sed 's/ /-/g' | sed 's/[^a-zA-Z0-9가-힣ㄱ-ㅎㅏ-ㅣ_.-]//g')
  output_file="$TARGET_DIR/$safe_title"
  content=$(cat "$file" 2>/dev/null || echo "")
  filename_without_ext="${filename%.md}"
  title="$filename_without_ext"
  
  if [ -f "$output_file" ]; then
    echo "업데이트: $title"
  else
    echo "새로 발행: $title"
  fi
  
  content=$(echo "$content" | sed "s/$PUBLISH_TAG//g")
  
  # 이미지 처리 - 파일 내용에서 이미지 참조 확인 (Process images referenced in file)
  image_line=""
  dir=$(dirname "$file")
  
  # 옵시디언 위키 스타일 이미지 찾기 (![[filename.png]])
  found_images=()
  while IFS= read -r line; do
    # 조건문 분리 (Condition separation)
    if [[ "$line" == *"![["* ]]; then
      if [[ "$line" == *"]]"* ]]; then
        # 이미지 이름 추출 (Extract image name) - 정규 표현식 개선 (Improved regex)
        img_path=$(echo "$line" | sed -n 's/^.*!\[\[\([^]]\+\)\]\].*$/\1/p')
        if [ -n "$img_path" ]; then
          img_name=$(basename "$img_path")
          found_images+=("$img_name")
          
          # 첫 번째 이미지는 대표 이미지로 설정 (Set the first image as the featured image)
          if [ -z "$image_line" ]; then
            image_line="image: \"images/blog/$img_name\""
          fi
          
          # 이미지 파일 복사 (Copy image file)
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
  
  # 프론트매터 처리 (Process front matter)
  if [[ $content == ---* ]]; then
    front_matter=$(echo "$content" | awk 'BEGIN{flag=0} /^---/{flag++; print; next} flag==1{print} flag==2{exit}')
    rest_content=$(echo "$content" | awk 'BEGIN{flag=0} /^---/{flag++} flag==2{print}' | tail -n +2)
    
    if ! grep -q "^draft:" <<<"$front_matter"; then
      front_matter=$(echo "$front_matter" | sed '/^---$/a draft: false')
    fi
    
    if ! grep -q "^title:" <<<"$front_matter"; then
      front_matter=$(echo "$front_matter" | sed '/^---$/a title: "'"$title"'"')
    else
      front_matter=$(echo "$front_matter" | sed 's/^title:.*$/title: "'"$title"'"/')
    fi
    
    if [ -n "$image_line" ]; then
      if grep -q "^image:" <<<"$front_matter"; then
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
        echo "$front_matter" | sed '/^---$/a '"$image_line" > /tmp/front_matter.tmp
        front_matter=$(cat /tmp/front_matter.tmp)
        rm /tmp/front_matter.tmp
      fi
    else
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
    
    final_content="${front_matter}${rest_content}"
  else
    if [[ $content == \#* ]]; then
      content_without_title=$(echo "$content" | tail -n +2)
    else
      content_without_title="$content"
    fi
    
    date=$(date +"%Y-%m-%d")
    if [ -n "$image_line" ]; then
      final_content="---
title: \"$title\"
date: $date
draft: false
$image_line
---

$content_without_title"
    else
      final_content="---
title: \"$title\"
date: $date
draft: false
---

$content_without_title"
    fi
  fi
  
  temp_content="$final_content"
  
  for img_name in "${found_images[@]}"; do
    temp_content=$(echo "$temp_content" | sed "s|!\[\[$img_name\]\]|{{< image src=\"images/blog/$img_name\" >}}|g")
  done
  
  echo "$temp_content" > "$output_file"
done

echo "발행 작업 완료: $PUBLISH_TAG 태그가 있는 노트를 발행하고, 태그가 제거된 노트는 발행 취소했습니다."

echo "변경사항 Git에 커밋 및 푸시 중..."
git add .
git commit -m "Update blog posts: $(date +'%Y-%m-%d %H:%M:%S')"
git push

echo "완료! GitHub Actions가 사이트를 빌드하고 배포할 것입니다."
