#!/bin/bash

# 환경 설정
export PATH="$PATH:/opt/homebrew/bin"

# 설정 - 경로를 실제 환경에 맞게 수정 (따옴표로 경로 처리)
VAULT_DIR="/Users/myjoo/Library/Mobile Documents/iCloud~md~obsidian/Documents/myjoo"
BLOG_DIR="/Users/myjoo/Documents/blog"
TARGET_DIR="$BLOG_DIR/content/english/blog"
IMAGE_DIR="$BLOG_DIR/assets/images/blog"
PUBLISH_TAG="#publish"

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

# PUBLISH_TAG가 있는 노트 찾기
echo "#publish 태그가 있는 노트 찾는 중..."
if [ -d "$VAULT_DIR" ]; then
  # 태그가 있는 파일 목록 생성
  # 파일명 처리 문제를 해결하기 위해 find -print0와 xargs -0 사용
  # 처음 3줄만 검사하도록 head -n 3 추가
  to_publish_files=$(find "$VAULT_DIR" -type f -name "*.md" -print0 | xargs -0 -I{} sh -c 'if head -n 3 "{}" | grep -q "'$PUBLISH_TAG'"; then echo "{}"; fi' 2>/dev/null || echo "")
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
    content=$(cat "$file" 2>/dev/null || echo "")
    if [[ $content == \#* ]]; then
      title=$(echo "$content" | head -n 1 | sed 's/^# //')
    elif grep -q "^title:" <<<"$content"; then
      title=$(grep -m 1 "^title:" <<<"$content" | sed 's/^title: *"\(.*\)".*$/\1/')
    else
      title="${file##*/}"
      title="${title%.md}"
    fi
    publish_titles+=("$title")
  fi
done

# 발행 취소할 파일 찾기
for file in $published_files; do
  if [ -f "$file" ]; then
    # 파일 이름만 추출
    base_filename=$(basename "$file")
    
    # _index.md와 post-숫자.md 패턴은 삭제에서 제외
    if [[ "$base_filename" == "_index.md" || "$base_filename" =~ ^post-[0-9]+\.md$ ]]; then
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
  
  # 제목 추출
  if [[ $content == \#* ]]; then
    title=$(echo "$content" | head -n 1 | sed 's/^# //')
  elif grep -q "^title:" <<<"$content"; then
    title=$(grep -m 1 "^title:" <<<"$content" | sed 's/^title: *"\(.*\)".*$/\1/')
  else
    title="${filename%.md}"
  fi
  
  # 발행 상태 확인
  if [ -f "$output_file" ]; then
    echo "업데이트: $title"
  else
    echo "새로 발행: $title"
  fi
  
  # PUBLISH_TAG 제거
  content=$(echo "$content" | sed "s/$PUBLISH_TAG//g")
  
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
      front_matter=$(echo "$front_matter" | sed '/^---$/a title: "'"$title"'"')
    fi
    
    # 최종 내용 조합
    final_content="${front_matter}${rest_content}"
  else
    # 프론트매터가 없는 경우
    # 첫 번째 줄이 # 으로 시작하면 제목으로 사용하고 본문에서 제외
    if [[ $content == \#* ]]; then
      content_without_title=$(echo "$content" | tail -n +2)
    else
      content_without_title="$content"
    fi
    
    # 프론트매터 추가
    date=$(date +"%Y-%m-%d")
    final_content="---
title: \"$title\"
date: $date
draft: false
---

$content_without_title"
  fi
  
  # 파일 저장
  echo "$final_content" > "$output_file"
  
  # 이미지 처리
  dir=$(dirname "$file")
  
  # 첨부 파일 처리 - 옵시디언 Wiki 링크 스타일 (![[ ]])
  grep -o "!\[\[.*\]\]" "$file" 2>/dev/null | sed 's/!\[\[\(.*\)\]\]/\1/g' | while read -r img; do
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
    sed -i '' "s|!\[\[$img\]\]|{{< image src=\"images/blog/$img_name\" >}}|g" "$output_file" 2>/dev/null || true
  done
  
  # Markdown 이미지 링크 스타일 (![]())
  grep -o "!\[.*\](.*)" "$file" 2>/dev/null | sed 's/!\[.*\](\(.*\))/\1/g' | while read -r img; do
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
        sed -i '' "s|!\\[.*\\]($img)|{{< image src=\"images/blog/$img_name\" caption=\"$img_alt\" >}}|g" "$output_file" 2>/dev/null || true
      else
        sed -i '' "s|!\\[.*\\]($img)|{{< image src=\"images/blog/$img_name\" >}}|g" "$output_file" 2>/dev/null || true
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