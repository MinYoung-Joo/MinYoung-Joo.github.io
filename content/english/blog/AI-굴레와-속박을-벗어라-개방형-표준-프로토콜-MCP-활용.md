---
title: "AI, 굴레와 속박을 벗어라-개방형 표준 프로토콜 MCP 활용"
date: 2025-03-08
draft: false
---


## MCP(Model Context Protocol)란?

MCP(Model Context Protocol)는 Anthropic이 2024년 11월에 공개한 개방형 프로토콜로, AI 모델이 다양한 데이터 소스와 안전하게 연결될 수 있도록 하는 표준입니다. 이를 통해 Claude와 같은 AI 모델이 코드 저장소(GitHub, GitLab), API(Google Maps, YouTube, Brave), 비즈니스 도구(Slack, Notion) 및 로컬 개발 환경과 같은 외부 시스템과 상호작용할 수 있습니다.

## MCP 작동 방식

MCP는 클라이언트-호스트-서버 아키텍처로 작동합니다:

- **MCP 호스트**: Claude Desktop와 같은 애플리케이션으로, MCP를 사용하여 다양한 리소스와 상호작용합니다.
    
- **MCP 클라이언트**: 호스트 내의 구성 요소로, 특정 서버와 직접적인 일대일 연결을 설정합니다.
    
- **MCP 서버**: MCP 프레임워크를 통해 특정 기능을 제공하도록 설계된 작은 프로그램입니다.
    
- **로컬 리소스**: 파일, 데이터베이스 등 컴퓨터에 있는 리소스로, MCP 서버가 안전하게 접근할 수 있습니다.
    
- **원격 리소스**: API나 클라우드 기반 서비스와 같은 외부 온라인 리소스입니다.
    

{{< image src="images/blog/1741329758693.png" >}}

## Claude Desktop에서 MCP 설정하기

### 1. Claude Desktop 설치하기

먼저 [Claude Desktop](https://claude.ai/download)을 다운로드하고 설치합니다. 현재 macOS와 Windows를 지원하며, Linux는 아직 지원되지 않습니다.

### 2. 구성 파일 생성하기

**macOS의 경우:**

1. 터미널을 열고 다음 명령어를 실행합니다:
    
    ```
    open ~/Library/Application\ Support/Claude
    ```
    
2. 구성 파일이 없다면 다음 명령어로 생성합니다:
    
    ```
    touch ~/Library/Application\ Support/Claude/claude_desktop_config.json
    ```
    

**Windows의 경우:**

1. `%APPDATA%\Claude` 폴더로 이동합니다.
    
2. `claude_desktop_config.json` 파일을 생성합니다.
    

### 3. MCP 서버 설치 및 구성하기

예를 들어, Brave Search MCP 도구를 설치하려면:

1. 터미널에서 다음 명령어를 실행합니다:
    
    ```
    npm install -g @modelcontextprotocol/server-brave-search
    ```
    
2. [Brave 개발자 사이트](https://brave.com/search/api/)에서 API 키를 발급받습니다.
    
3. 구성 파일(`claude_desktop_config.json`)을 열고 다음 내용을 추가합니다:
    
    ```
    {
      "mcpServers": {
        "brave-search": {
          "command": "npx",
          "args": [
            "-y",
            "@modelcontextprotocol/server-brave-search"
          ],
          "env": {
            "BRAVE_API_KEY": "YOUR_API_KEY_HERE"
          }
        }
      }
    }
    ```
    

### 4. Claude Desktop 재시작

구성 파일을 저장한 후 Claude Desktop을 재시작합니다. 재시작 후 입력창 오른쪽 하단에 망치(🔨) 아이콘이 표시되면 MCP 서버가 성공적으로 연결된 것입니다.

## 무엇이 가능한가?

### 예시 1: 웹 검색 (Brave Search)

**설정 방법:** 위에서 설명한 대로 Brave Search MCP 서버를 설정합니다.

**활용 예시:**

- "비트코인의 현재 가격은 얼마인가요?"
    
- "최근 맨체스터 유나이티드 경기 결과를 요약해줘"
    
- "2025년 인공지능 트렌드에 대해 알려줘"
    

Claude는 각 대화 시작 시 도구 사용 권한을 요청하며, 허용하면 Brave 검색을 통해 최신 정보를 제공합니다.

### 예시 2: 파일 시스템 접근

**설정 방법:**

```
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/사용자명/Desktop",
        "/Users/사용자명/Documents"
      ]
    }
  }
}
```

**활용 예시:**

- "데스크톱에 있는 모든 Python 파일을 찾아서 내용을 요약해줘"
    
- "Documents 폴더에 'meeting_notes.txt'라는 파일을 만들고 오늘 회의 내용을 정리해줘"
    
- "Desktop에 있는 이미지 파일들을 'Images' 폴더로 모두 이동시켜줘"
    

### 예시 3: GitHub 연동

**설정 방법:**

```
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "your_github_token"
      }
    }
  }
}
```

**활용 예시:**

- "내 GitHub 저장소 목록을 보여줘"
    
- "project-x 저장소의 최근 커밋 내역을 분석해줘"
    
- "오픈된 PR 중에서 코드 리뷰가 필요한 것들을 찾아줘"
    

### 예시 4: 데이터베이스 연결 (PostgreSQL)

**설정 방법:**

```
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgresql"],
      "env": {
        "DATABASE_URL": "postgresql://사용자명:비밀번호@localhost:5432/데이터베이스명"
      }
    }
  }
}
```

**활용 예시:**

- "데이터베이스의 모든 테이블 구조를 보여줘"
    
- "users 테이블에서 가입일이 2023년 이후인 사용자 수를 계산해줘"
    
- "sales 테이블의 월별 매출 추이를 분석해줘"
    

### 예시 5: 여러 MCP 서버 동시 사용

여러 MCP 서버를 동시에 구성하여 Claude의 기능을 확장할 수 있습니다:

```
{
  "mcpServers": {
    "brave-search": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-brave-search"],
      "env": {
        "BRAVE_API_KEY": "your_brave_api_key"
      }
    },
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/사용자명/Desktop",
        "/Users/사용자명/Documents"
      ]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "your_github_token"
      }
    }
  }
}
```

이렇게 설정하면 Claude는 상황에 따라 적절한 도구를 선택하여 사용할 수 있습니다.

### 예시 6: OpenAPI 명세를 통한 API 연동 (emcee 활용)

emcee는 OpenAPI 명세를 가진 웹 애플리케이션을 MCP 서버로 변환해주는 도구입니다.

**설정 방법:**

```
{
  "mcpServers": {
    "weather": {
      "command": "emcee",
      "args": [
        "https://api.weather.gov/openapi.json"
      ]
    }
  }
}
```

**활용 예시:**

- "포틀랜드의 현재 날씨는 어때?"
    
- "서울의 주간 날씨 예보를 알려줘"
    

## 주의사항 및 팁

1. **보안**: MCP 서버는 사용자 계정의 권한으로 실행되므로, 신뢰할 수 있는 소스의 서버만 추가해야 합니다.
    
2. **인증 정보 관리**: API 키나 토큰과 같은 민감한 정보는 안전하게 관리해야 합니다. 1Password와 같은 도구를 사용하여 참조할 수 있습니다:
    
    ```
    {
      "mcpServers": {
        "twitter": {
          "command": "emcee",
          "args": [
            "--bearer-auth=op://shared/x/credential",
            "https://api.twitter.com/2/openapi.json"
          ]
        }
      }
    }
    ```
    
3. **문제 해결**: 문제가 발생할 경우 로그 파일을 확인하세요:
    
    - macOS: `~/Library/Logs/Claude/mcp*.log`
        
    - Windows: `%APPDATA%\Claude\logs\mcp*.log`
        
4. **MCP 인스펙터 사용**: MCP 서버를 테스트하고 디버깅하려면 MCP 인스펙터를 사용할 수 있습니다:
    
    ```
    npx @modelcontextprotocol/inspector emcee https://api.weather.gov/openapi.json
    ```
    

## MCP의 미래

Claude Desktop에서 MCP를 활용하면 일상적인 작업을 자동화하고 생산성을 크게 향상시킬 수 있습니다. MCP는 AI 모델이 다양한 데이터 소스와 도구에 접근할 수 있게 함으로써, 더 관련성 높고 유용한 응답을 생성할 수 있도록 돕습니다. Anthropic은 MCP를 협업적이고 오픈 소스 프로젝트로 개발하고 있으며, 개발자들이 자신만의 MCP 서버를 구축하고 공유할 수 있도록 장려하고 있습니다. Block, Apollo, Zed, Replit, Codeium, Sourcegraph 등의 기업들이 MCP를 자사 시스템에 통합하는 중입니다.  
  
그밖에도 [Claude Computer use (beta)](https://docs.anthropic.com/en/docs/agents-and-tools/computer-use)나 [OpenAI Operator](https://operator.chatgpt.com/)(Pro 요금제 이상)와 같은 에이전트 도구와 조합하면 더욱 풍부한 기능을 구현할 수 있을 것으로 생각됩니다. 이번 기회에 진짜 나를 위한 AI 비서를 만들어 보는 건 어떨까요?

## 참고 링크

- [Introducing the Model Context Protocol](https://www.anthropic.com/news/model-context-protocol)
    
- [Model Context Protocol For Claude Desktop Users](https://modelcontextprotocol.io/quickstart/user)
    
- [How to Use MCP Tools on Claude Desktop App and Automate Your Daily Tasks](https://medium.com/@pedro.aquino.se/how-to-use-mcp-tools-on-claude-desktop-app-and-automate-your-daily-tasks-1c38e22bc4b0)
    
- [Model Context Protocol (MCP) Anthropic 개발 방법: 위키독스(한글)](https://wikidocs.net/book/17027)
    
- [Awesome MCP Servers: MCP 지원 서버 목록](https://github.com/appcypher/awesome-mcp-servers?tab=readme-ov-file)
    
- [emcee - OpenAPI를 MCP로 변환](https://github.com/loopwork-ai/emcee)
    
- [Wanaku - 오픈소스 MCP 라우터](https://github.com/wanaku-ai/wanaku)
    
- [Model Context Protocol 깃허브](https://github.com/modelcontextprotocol)
