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

# PUBLISH_TAG가 있는 노트 찾기 - 특수문자가 있는 파일명도 안전하게 처리
echo "#publish 태그가 있는 노트 찾는 중..."
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
  
  # 이미지 처리 - 간소화된 접근 (이미지 정보 없음)
  image_line=""
  dir=$(dirname "$file")
  
  # 특수 이미지 처리 - 전체 이미지 복사
  # 옵시디언에서 github.io 블로그로 원하는 글만 선택적으로 발행하기.md 파일인 경우
  base_filename=$(basename "$file")
  if [[ "$base_filename" == "옵시디언에서 github.io 블로그로 원하는 글만 선택적으로 발행하기.md" ]]; then
    # attachments 디렉토리의 특정 이미지 파일
    if [ -f "$VAULT_DIR/attachments/screenshot_hu14038609273344937620.png" ]; then
      cp "$VAULT_DIR/attachments/screenshot_hu14038609273344937620.png" "$IMAGE_DIR/"
      echo "  이미지 복사: attachments/screenshot_hu14038609273344937620.png"
      image_line="image: \"images/blog/screenshot_hu14038609273344937620.png\""
    fi
  elif [[ "$base_filename" == "AI, 굴레와 속박을 벗어라-개방형 표준 프로토콜(MCP) 활용.md" ]]; then
    if [ -f "$VAULT_DIR/attachments/1741329758693.png" ]; then
      cp "$VAULT_DIR/attachments/1741329758693.png" "$IMAGE_DIR/"
      echo "  이미지 복사: attachments/1741329758693.png"
      image_line="image: \"images/blog/1741329758693.png\""
    fi
  fi
  
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
    else
      # 기존 title 값을 새로 찾은 title로 업데이트
      front_matter=$(echo "$front_matter" | sed 's/^title:.*$/title: "'"$title"'"/')
    fi
    
    # image 필드 처리
    if [ -n "$image_line" ]; then
      if grep -q "^image:" <<<"$front_matter"; then
        # 기존 image 필드가 있으면 교체
        front_matter=$(echo "$front_matter" | sed 's|^image:.*|'"$image_line"'|')
      else
        # 필드가 없으면 추가
        front_matter=$(echo "$front_matter" | sed '/^---$/a '"$image_line"'')
      fi
    else
      # 이미지가 없는 경우, image 필드 제거
      front_matter=$(echo "$front_matter" | sed '/^image:/d')
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
  
  # 파일 저장
  echo "$final_content" > "$output_file"
  
  # 이미지 태그 변환 - 특수 파일에 대해 직접 치환
  if [[ "$base_filename" == "옵시디언에서 github.io 블로그로 원하는 글만 선택적으로 발행하기.md" ]]; then
    sed -i '' 's/!\[\[screenshot_hu14038609273344937620.png\]\]/{{< image src="images\/blog\/screenshot_hu14038609273344937620.png" >}}/g' "$output_file"
  elif [[ "$base_filename" == "AI, 굴레와 속박을 벗어라-개방형 표준 프로토콜(MCP) 활용.md" ]]; then
    sed -i '' 's/!\[\[1741329758693.png\]\]/{{< image src="images\/blog\/1741329758693.png" >}}/g' "$output_file"
  fi
done

echo "발행 작업 완료: $PUBLISH_TAG 태그가 있는 노트를 발행하고, 태그가 제거된 노트는 발행 취소했습니다."

# 변경사항 Git에 커밋 및 푸시
echo "변경사항 Git에 커밋 및 푸시 중..."
git add .
git commit -m "Update blog posts: $(date +'%Y-%m-%d %H:%M:%S')"
git push

echo "완료! GitHub Actions가 사이트를 빌드하고 배포할 것입니다."