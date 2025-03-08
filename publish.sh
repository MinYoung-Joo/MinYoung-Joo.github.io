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
  
  # 이미지 처리 - 단순화된 접근법
  image_str=""
  dir=$(dirname "$file")
  
  # 이미지 검색 및 처리 - 라인별 처리가 아닌 패턴 검색 사용
  if grep -F "![[" "$file" > /dev/null 2>&1; then
    # 첫 번째 이미지 태그 찾기 (임시 파일 사용)
    grep -F "![[" "$file" | head -n 1 > /tmp/img_line.txt
    
    # 읽은 줄에서 이미지 이름 추출
    if [ -s /tmp/img_line.txt ]; then
      raw_img_line=$(cat /tmp/img_line.txt)
      
      # 정규식을 사용하지 않고 간단한 문자열 처리로 이미지 이름 추출
      img_name=""
      start_marker="![["
      end_marker="]]"
      
      # 시작 위치 찾기
      start_pos=$(echo "$raw_img_line" | awk -v marker="$start_marker" '{ print index($0, marker) }')
      
      if [ $start_pos -gt 0 ]; then
        # 시작 위치에서 마커 길이만큼 이동
        start_pos=$((start_pos + ${#start_marker}))
        part_after_start=${raw_img_line:$start_pos-1}
        
        # 종료 위치 찾기
        end_pos=$(echo "$part_after_start" | awk -v marker="$end_marker" '{ print index($0, marker) }')
        
        if [ $end_pos -gt 0 ]; then
          # 이미지 이름 추출
          img_name=${part_after_start:0:$end_pos-1}
          
          # 이미지 파일 확인 및 복사
          if [ -n "$img_name" ]; then
            if [ -f "$VAULT_DIR/attachments/$img_name" ]; then
              echo "  이미지 복사: attachments/$img_name"
              cp "$VAULT_DIR/attachments/$img_name" "$IMAGE_DIR/$img_name"
              
              # 명시적인 image 문자열 설정
              image_str="image: \"images/blog/$img_name\""
            elif [ -f "$dir/$img_name" ]; then
              echo "  이미지 복사: $img_name"
              cp "$dir/$img_name" "$IMAGE_DIR/$img_name"
              
              # 명시적인 image 문자열 설정
              image_str="image: \"images/blog/$img_name\""
            fi
          fi
        fi
      fi
    fi
    
    rm /tmp/img_line.txt
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
    
    # image 필드 처리 - 라인별 접근법 사용
    if [ -n "$image_str" ]; then
      # 임시 파일에 새 프론트매터 작성
      echo "---" > /tmp/frontmatter.txt
      echo "$front_matter" | grep -v "^---" | grep -v "^image:" | while read -r line; do
        echo "$line" >> /tmp/frontmatter.txt
      done
      
      # 이미지 라인 추가
      echo "$image_str" >> /tmp/frontmatter.txt
      echo "---" >> /tmp/frontmatter.txt
      
      # 새 프론트매터 읽기
      front_matter=$(cat /tmp/frontmatter.txt)
      rm /tmp/frontmatter.txt
    else
      # 이미지가 없는 경우 image 필드 제거
      new_frontmatter=""
      echo "---" > /tmp/frontmatter.txt
      echo "$front_matter" | grep -v "^---" | grep -v "^image:" >> /tmp/frontmatter.txt
      echo "---" >> /tmp/frontmatter.txt
      front_matter=$(cat /tmp/frontmatter.txt)
      rm /tmp/frontmatter.txt
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
    if [ -n "$image_str" ]; then
      final_content="---
title: \"$title\"
date: $date
draft: false
$image_str
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
  
  # 임시 파일에 일단 저장
  echo "$final_content" > /tmp/final_content.txt
  
  # 이미지 태그 변환 - 이미지 자체의 태그 변환은 별도 처리
  if [ -f "$IMAGE_DIR/screenshot_hu14038609273344937620.png" ]; then
    # 해당 이미지가 있는 경우 변환
    cat /tmp/final_content.txt | sed 's|!\[\[screenshot_hu14038609273344937620.png\]\]|{{< image src="images/blog/screenshot_hu14038609273344937620.png" >}}|g' > "$output_file"
  elif [ -f "$IMAGE_DIR/1741329758693.png" ]; then
    # 다른 이미지가 있는 경우 변환
    cat /tmp/final_content.txt | sed 's|!\[\[1741329758693.png\]\]|{{< image src="images/blog/1741329758693.png" >}}|g' > "$output_file"
  else
    # 이미지가 없는 경우 그대로 사용
    cp /tmp/final_content.txt "$output_file"
  fi
  
  rm /tmp/final_content.txt
done

echo "발행 작업 완료: $PUBLISH_TAG 태그가 있는 노트를 발행하고, 태그가 제거된 노트는 발행 취소했습니다."

# 변경사항 Git에 커밋 및 푸시
echo "변경사항 Git에 커밋 및 푸시 중..."
git add .
git commit -m "Update blog posts: $(date +'%Y-%m-%d %H:%M:%S')"
git push

echo "완료! GitHub Actions가 사이트를 빌드하고 배포할 것입니다."