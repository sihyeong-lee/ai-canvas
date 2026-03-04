# AI Canvas 초급 매뉴얼 초안 (Step 1, 내부 DB 미사용)

기준 문서: `step1.md`, `act.md`

## 1) 목적과 범위
- 이 문서는 Step 1 플로우만 다룹니다.
- 내부 DB(`Cases`, `Evidence_Facts`, `Facts`)는 사용하지 않습니다.
- `노동법 RAG` PDF는 AI Canvas에 업로드하지 않습니다.
- 법령/판례/행정해석은 외부 API로만 조회합니다.

## 2) 고정 규칙
- 모든 API URL에 `OC=tud1211`를 포함합니다.
- 커스텀 API 노드에는 `OC` 입력칸이 없으므로 URL 쿼리에 직접 넣습니다.
- 결론은 공식근거 2건 미만이면 차단합니다.

## 3) Step 1 노드 목록 (정확한 노드명)
1. 에이전트
2. 에이전트 메시지 가로채기
3. 에이전트 프롬프트_질의정규화
4. 파이썬_정규화파싱
5. 파이썬_URL생성
6. API_법령목록
7. API_판례목록
8. API_해석목록
9. 파이썬_법령상세URL
10. 파이썬_판례상세URL
11. 파이썬_해석상세URL
12. API_법령본문
13. API_판례본문
14. API_해석본문
15. 데이터 연결_근거통합
16. 에이전트 프롬프트_답변생성
17. 파이썬_검열게이트
18. 데이터 조건 분기
19. 프롬프트_차단응답
20. 에이전트로 전달

## 4) 정확한 포트 연결 맵
| From 노드 | From 포트/컬럼 | To 노드 | To 포트/컬럼 |
|---|---|---|---|
| 에이전트 | 메시지 출력 | 에이전트 메시지 가로채기 | 메시지 입력 |
| 에이전트 메시지 가로채기 | 가로챈 메시지 | 에이전트 프롬프트_질의정규화 | 프롬프트 입력 |
| 에이전트 프롬프트_질의정규화 | `normalized_json` | 파이썬_정규화파싱 | 입력 데이터셋 |
| 파이썬_정규화파싱 | `issue_keywords_csv`,`law_query`,`precedent_query`,`interpretation_query`,`date_from`,`date_to`,`must_have` | 파이썬_URL생성 | 입력 데이터셋 |
| 파이썬_URL생성 | `law_list_url` | API_법령목록 | URL 컬럼 |
| 파이썬_URL생성 | `prec_list_url` | API_판례목록 | URL 컬럼 |
| 파이썬_URL생성 | `expc_list_url` | API_해석목록 | URL 컬럼 |
| API_법령목록 | 목록 결과(`ID`,`MST` 포함) | 파이썬_법령상세URL | 입력 데이터셋 |
| API_판례목록 | 목록 결과(`ID`) | 파이썬_판례상세URL | 입력 데이터셋 |
| API_해석목록 | 목록 결과(`ID`) | 파이썬_해석상세URL | 입력 데이터셋 |
| 파이썬_법령상세URL | `law_detail_url` | API_법령본문 | URL 컬럼 |
| 파이썬_판례상세URL | `prec_detail_url` | API_판례본문 | URL 컬럼 |
| 파이썬_해석상세URL | `expc_detail_url` | API_해석본문 | URL 컬럼 |
| API_법령본문 | 본문 결과 | 데이터 연결_근거통합 | 입력1 |
| API_판례본문 | 본문 결과 | 데이터 연결_근거통합 | 입력2 |
| API_해석본문 | 본문 결과 | 데이터 연결_근거통합 | 입력3 |
| 데이터 연결_근거통합 | 통합 근거셋 | 에이전트 프롬프트_답변생성 | 프롬프트 컨텍스트 |
| 에이전트 프롬프트_답변생성 | `draft_answer` (+ `source_urls`, `official_evidence_count`) | 파이썬_검열게이트 | 입력 데이터셋 |
| 파이썬_검열게이트 | `is_pass`,`fail_reason`,`official_evidence_count` | 데이터 조건 분기 | 조건 입력 |
| 데이터 조건 분기(참) | `draft_answer` | 에이전트로 전달 | 응답 입력 |
| 데이터 조건 분기(거짓) | 분기 트리거 | 프롬프트_차단응답 | 프롬프트 입력 |
| 프롬프트_차단응답 | 차단 메시지 | 에이전트로 전달 | 응답 입력 |

## 5) 프롬프트 원문
### 노드 3: 에이전트 프롬프트_질의정규화
```text
역할: 징계 사건 입력을 공식 검색용 구조로 정규화
반드시 JSON만 출력
스키마:
{
  "case_type": "",
  "issue_keywords": [""],
  "law_query": "",
  "precedent_query": "",
  "interpretation_query": "",
  "incident_date": "YYYY-MM-DD 또는 빈 문자열",
  "date_from": "YYYYMMDD 또는 빈 문자열",
  "date_to": "YYYYMMDD 또는 빈 문자열",
  "must_have": ["법령명","조문","시행일","법원","선고일","사건번호"]
}
규칙:
- 사용자 입력 의미를 바꾸지 말 것
- `issue_keywords`는 빈 값 금지(최소 1개)
- `law_query`, `precedent_query`, `interpretation_query` 중 최소 1개는 채울 것
- 정보가 부족하면 기본값 `징계` 사용
- 키워드는 3~7개 권장(최소 1개)
```

### 노드 16: 에이전트 프롬프트_답변생성
```text
역할: 근거 기반 징계 검토 보고서 작성
금지: 근거에 없는 단정, 출처 없는 결론
반드시 아래 템플릿을 제목/순서/아이콘/기호까지 그대로 사용
정보가 없으면 빈칸 대신 반드시 `부재`라고 기재
링크는 원문 URL만 허용
법령 1개 + 판례/해석 1개 이상 없으면 `♟️ 종합 판단` 작성 금지
Step1에서는 내부DB를 연결하지 않으므로 `🏢 내부DB 참고`는 기본적으로 `부재`로 기재

[🟢 Online Mode | {timestamp}] >
🔍 Search Strategy >
> {수집 전략 요약}
> [🌐 웹 서치 적용: {도메인 목록}]

🧊 사실관계 요약
- {사용자 진술 요약}
- {불명확 포인트}

⚖️ 쟁점
- {쟁점1}
- {쟁점2}

📚 적용 법령
- 법령명: {name}
- 조문: {article}
- 시행일: {effective_date}
- 해석 포인트: {point}

🧑‍⚖️ 관련 판례
- 법원: {court}
- 선고일: {date}
- 사건번호: {case_no}
- 판시요지: {holding}
- 근거 링크: {url}

🏢 내부DB 참고
- 사내 규정: {rule_name}
- 유사 징계사례: {case_id / 요약}
- 차이점: {difference}

♟️ 종합 판단
- {종합 의견}

🚀 다음 액션
- {필요 증거}
- {문서/절차}
- {기한}

[불확실/부재]
- {근거 부족 항목 명시}
```

### 노드 19: 프롬프트_차단응답
```text
다음 3줄을 반드시 포함해 한국어로 짧게 답변하세요.
1) 현재 공식근거가 부족하여 결론을 제시하지 않습니다
2) 추가 사실/기간/키워드가 필요합니다
3) 불확실/부재 항목: {fail_reason}
```

## 6) API URL 고정값 (모두 `OC=tud1211` 포함)
- 법령 목록: `https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&target=eflaw&type=JSON`
- 법령 본문: `https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=eflaw&type=JSON`
- 판례 목록: `https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&target=prec&type=JSON`
- 판례 본문: `https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=prec&type=JSON`
- 해석례 목록: `https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&target=expc&type=JSON`
- 해석례 본문: `https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=expc&type=JSON`

## 7) Python 노드 코드 (AI Canvas 고정 스캐폴드 전용)
중요: AI Canvas Python 노드는 아래 형식의 상/하단이 고정이며, **`execute()` 함수 내부만 입력 가능**합니다.
주의: 일부 환경에서는 중간 코드에 `def`, `return`, `yield`가 있으면 실행이 차단됩니다. 아래 중간 코드는 해당 키워드 없이 작성했습니다.

```python
import math
import random
import datetime
import collections
import itertools
import json
import re
import csv
import sklearn      # 1.3.2
import pandas as pd # 1.4.3
import numpy as np  # 1.23.1
import oracledb
import pyodbc
import mariadb
import psycopg2

def execute(
        x: List[pd.DataFrame],
        dataset: pd.DataFrame
) -> pd.DataFrame:
    # 여기만 입력 가능
    ...
    return result
```

아래 코드는 모두 **`execute()` 내부에만 붙여넣는 코드**입니다.

### 노드 4: 파이썬_정규화파싱 (중간 코드)
```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

if "normalized_json" in df.columns:
    source_col = "normalized_json"
elif "output_response" in df.columns:
    source_col = "output_response"
else:
    source_col = None

rows = []
for row in df.to_dict(orient="records"):
    raw = row.get(source_col, "") if source_col else ""
    obj = {}

    if isinstance(raw, dict):
        obj = raw
    else:
        text = "" if raw is None else str(raw).strip()
        if text and text.lower() != "nan":
            try:
                obj = json.loads(text)
            except Exception:
                m = re.search(r"\{.*\}", text, re.S)
                if m:
                    try:
                        obj = json.loads(m.group(0))
                    except Exception:
                        obj = {}

    kws = obj.get("issue_keywords", [])
    if isinstance(kws, str):
        kws = [x.strip() for x in re.split(r"[,\s/|]+", kws) if x.strip()]
    elif isinstance(kws, list):
        cleaned = []
        for x in kws:
            if x is None:
                continue
            sx = str(x).strip()
            if sx and sx.lower() != "nan":
                cleaned.append(sx)
        kws = cleaned
    else:
        kws = []

    law_query = obj.get("law_query", "")
    if law_query is None:
        law_query = ""
    else:
        try:
            if pd.isna(law_query):
                law_query = ""
        except Exception:
            pass
    law_query = str(law_query).strip()
    if law_query.lower() == "nan":
        law_query = ""

    precedent_query = obj.get("precedent_query", "")
    if precedent_query is None:
        precedent_query = ""
    else:
        try:
            if pd.isna(precedent_query):
                precedent_query = ""
        except Exception:
            pass
    precedent_query = str(precedent_query).strip()
    if precedent_query.lower() == "nan":
        precedent_query = ""

    interpretation_query = obj.get("interpretation_query", "")
    if interpretation_query is None:
        interpretation_query = ""
    else:
        try:
            if pd.isna(interpretation_query):
                interpretation_query = ""
        except Exception:
            pass
    interpretation_query = str(interpretation_query).strip()
    if interpretation_query.lower() == "nan":
        interpretation_query = ""

    if not kws:
        fallback = " ".join([law_query, precedent_query, interpretation_query]).strip()
        if not fallback:
            for k in ["question", "query", "user_query", "user_input", "input_text", "message", "agent_message", "chat_message", "content", "text"]:
                v = row.get(k, "")
                if v is None:
                    v = ""
                else:
                    try:
                        if pd.isna(v):
                            v = ""
                    except Exception:
                        pass
                v = str(v).strip()
                if v.lower() == "nan":
                    v = ""
                if v and not v.startswith("{"):
                    fallback = v
                    break
        if fallback:
            toks = [t for t in re.split(r"[,\s/|]+", fallback) if t]
            kws = []
            for t in toks:
                st = str(t).strip()
                if st and st.lower() != "nan" and len(st) >= 2:
                    kws.append(st)
                if len(kws) >= 7:
                    break

    if not kws:
        kws = ["징계"]

    seed = " ".join(kws[:3]).strip() or "징계"
    if not law_query:
        law_query = seed
    if not precedent_query:
        precedent_query = seed
    if not interpretation_query:
        interpretation_query = seed

    must_have = obj.get("must_have", [])
    if isinstance(must_have, str):
        must_have = [x.strip() for x in must_have.split(",") if x.strip()]
    elif isinstance(must_have, list):
        cleaned = []
        for x in must_have:
            if x is None:
                continue
            sx = str(x).strip()
            if sx and sx.lower() != "nan":
                cleaned.append(sx)
        must_have = cleaned
    else:
        must_have = []
    if not must_have:
        must_have = ["법령명", "조문", "시행일", "법원", "선고일", "사건번호"]

    date_from = obj.get("date_from", "")
    if date_from is None:
        date_from = ""
    else:
        try:
            if pd.isna(date_from):
                date_from = ""
        except Exception:
            pass
    date_from = str(date_from).strip()
    if date_from.lower() == "nan":
        date_from = ""

    date_to = obj.get("date_to", "")
    if date_to is None:
        date_to = ""
    else:
        try:
            if pd.isna(date_to):
                date_to = ""
        except Exception:
            pass
    date_to = str(date_to).strip()
    if date_to.lower() == "nan":
        date_to = ""

    rows.append({
        "issue_keywords_csv": ", ".join(kws),
        "law_query": law_query,
        "precedent_query": precedent_query,
        "interpretation_query": interpretation_query,
        "date_from": date_from,
        "date_to": date_to,
        "must_have": ",".join(must_have),
    })

result = pd.DataFrame(rows, columns=[
    "issue_keywords_csv",
    "law_query",
    "precedent_query",
    "interpretation_query",
    "date_from",
    "date_to",
    "must_have",
])
```

### 노드 5: 파이썬_URL생성 (중간 코드)
```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()
base = "https://www.law.go.kr/DRF/lawSearch.do?OC=tud1211&type=JSON"

rows = []
for _, r in df.iterrows():
    fallback = r.get("issue_keywords_csv", "")
    if fallback is None:
        fallback = ""
    else:
        try:
            if pd.isna(fallback):
                fallback = ""
        except Exception:
            pass
    fallback = str(fallback).strip()
    if fallback.lower() == "nan" or not fallback:
        fallback = "징계"

    lq = r.get("law_query", "")
    if lq is None:
        lq = ""
    else:
        try:
            if pd.isna(lq):
                lq = ""
        except Exception:
            pass
    lq = str(lq).strip()
    if lq.lower() == "nan" or not lq:
        lq = fallback

    pq = r.get("precedent_query", "")
    if pq is None:
        pq = ""
    else:
        try:
            if pd.isna(pq):
                pq = ""
        except Exception:
            pass
    pq = str(pq).strip()
    if pq.lower() == "nan" or not pq:
        pq = fallback

    eq = r.get("interpretation_query", "")
    if eq is None:
        eq = ""
    else:
        try:
            if pd.isna(eq):
                eq = ""
        except Exception:
            pass
    eq = str(eq).strip()
    if eq.lower() == "nan" or not eq:
        eq = fallback

    lq_enc = lq.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    pq_enc = pq.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    eq_enc = eq.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")

    rows.append({
        "law_query_used": lq,
        "prec_query_used": pq,
        "expc_query_used": eq,
        "law_list_url": f"{base}&target=eflaw&search=1&query={lq_enc}&display=5&page=1&sort=ddes",
        "prec_list_url": f"{base}&target=prec&search=1&query={pq_enc}&display=5&page=1&sort=ddes",
        "expc_list_url": f"{base}&target=expc&search=1&query={eq_enc}&display=5&page=1&sort=ddes",
    })

result = pd.DataFrame(rows, columns=[
    "law_query_used",
    "prec_query_used",
    "expc_query_used",
    "law_list_url",
    "prec_list_url",
    "expc_list_url",
])
```

### 노드 9: 파이썬_법령상세URL (중간 코드)
```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

rows = []
for _, r in df.iterrows():
    row = r.to_dict()
    idv = ""
    for k in ["ID", "id", "법령ID", "law_id"]:
        if k in row:
            v = row.get(k, "")
            if v is None:
                v = ""
            else:
                try:
                    if pd.isna(v):
                        v = ""
                except Exception:
                    pass
            v = str(v).strip()
            if v and v.lower() != "nan":
                idv = v
                break

    mstv = ""
    for k in ["MST", "mst", "법령일련번호"]:
        if k in row:
            v = row.get(k, "")
            if v is None:
                v = ""
            else:
                try:
                    if pd.isna(v):
                        v = ""
                except Exception:
                    pass
            v = str(v).strip()
            if v and v.lower() != "nan":
                mstv = v
                break

    idv_enc = idv.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    mstv_enc = mstv.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")

    if idv:
        url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=eflaw&ID={idv_enc}&type=JSON"
    elif mstv:
        url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=eflaw&MST={mstv_enc}&type=JSON"
    else:
        url = ""

    rows.append({"law_detail_url": url})

result = pd.DataFrame(rows, columns=["law_detail_url"])
```

### 노드 10: 파이썬_판례상세URL (중간 코드)
```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

rows = []
for _, r in df.iterrows():
    idv = r.get("ID", "")
    if idv is None or (hasattr(pd, "isna") and pd.isna(idv)):
        idv = r.get("id", "")
    if idv is None:
        idv = ""
    else:
        try:
            if pd.isna(idv):
                idv = ""
        except Exception:
            pass
    idv = str(idv).strip()
    if idv.lower() == "nan":
        idv = ""
    idv_enc = idv.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=prec&ID={idv_enc}&type=JSON" if idv else ""
    rows.append({"prec_detail_url": url})

result = pd.DataFrame(rows, columns=["prec_detail_url"])
```

### 노드 11: 파이썬_해석상세URL (중간 코드)
```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

rows = []
for _, r in df.iterrows():
    idv = r.get("ID", "")
    if idv is None or (hasattr(pd, "isna") and pd.isna(idv)):
        idv = r.get("id", "")
    if idv is None:
        idv = ""
    else:
        try:
            if pd.isna(idv):
                idv = ""
        except Exception:
            pass
    idv = str(idv).strip()
    if idv.lower() == "nan":
        idv = ""
    idv_enc = idv.replace("%", "%25").replace(" ", "%20").replace("#", "%23").replace("&", "%26").replace("+", "%2B")
    url = f"https://www.law.go.kr/DRF/lawService.do?OC=tud1211&target=expc&ID={idv_enc}&type=JSON" if idv else ""
    rows.append({"expc_detail_url": url})

result = pd.DataFrame(rows, columns=["expc_detail_url"])
```

### 노드 17: 파이썬_검열게이트 (중간 코드)
```python
df = dataset.copy() if isinstance(dataset, pd.DataFrame) else pd.DataFrame()

allow_hosts = (
    "law.go.kr",
    "open.law.go.kr",
    "portal.scourt.go.kr",
    "ecfs.scourt.go.kr",
)
must_slots = ["법령명", "조문", "시행일", "법원", "선고일", "사건번호"]
url_re = re.compile(r"https?://[^\s)\]]+")

rows = []
for _, r in df.iterrows():
    row = r.to_dict()
    draft = row.get("draft_answer", row.get("output_response", ""))
    if draft is None:
        draft = ""
    else:
        try:
            if pd.isna(draft):
                draft = ""
        except Exception:
            pass
    draft = str(draft).strip()
    if draft.lower() == "nan":
        draft = ""

    raw_urls = row.get("source_urls", "")
    urls = []
    if isinstance(raw_urls, list):
        for u in raw_urls:
            if u is None:
                continue
            try:
                if pd.isna(u):
                    continue
            except Exception:
                pass
            su = str(u).strip()
            if su and su.lower() != "nan":
                urls.append(su)
    else:
        text = raw_urls
        if text is None:
            text = ""
        else:
            try:
                if pd.isna(text):
                    text = ""
            except Exception:
                pass
        text = str(text).strip()
        if text.lower() == "nan":
            text = ""
        if text:
            if "|" in text:
                urls = [u.strip() for u in text.split("|") if u.strip()]
            else:
                urls = [u.strip() for u in re.split(r"[\s,]+", text) if u.strip().startswith("http")]

    if not urls:
        urls = url_re.findall(draft)

    official_urls = [u for u in urls if any(h in u for h in allow_hosts)]
    evidence = len(official_urls)
    raw_evidence = row.get("official_evidence_count", None)
    if raw_evidence is not None:
        try:
            evidence = int(raw_evidence)
        except Exception:
            evidence = len(official_urls)

    bad_domain = any(not any(h in u for h in allow_hosts) for u in urls) if urls else False
    missing = [s for s in must_slots if s not in draft]
    is_pass = (evidence >= 2) and (not bad_domain) and (len(missing) == 0)

    reasons = []
    if evidence < 2:
        reasons.append("official_evidence_count<2")
    if bad_domain:
        reasons.append("domain_not_allowed")
    if missing:
        reasons.append("missing_slots:" + ",".join(missing))
    if not urls:
        reasons.append("source_urls_missing")

    row["is_pass"] = bool(is_pass)
    row["official_evidence_count"] = int(evidence)
    row["fail_reason"] = " / ".join(reasons) if reasons else ""
    rows.append(row)

result = pd.DataFrame(rows)
```

## 8) 초급자 실행 순서
1. 새 캔버스 생성 후 노드 1~20 배치.
2. 3개 프롬프트 노드(3,16,19)에 본문 그대로 붙여넣기.
3. Python 노드(4,5,9,10,11,17)는 **`execute()` 내부 중간 코드만** 붙여넣기.
4. API 노드(6,7,8,12,13,14)는 URL 컬럼 모드로 연결.
5. `OC=tud1211` 포함 여부를 6개 API URL 모두에서 확인.
6. 테스트 질의 10건 실행 후, `is_pass`와 차단응답 동작 확인.

## 9) 주의사항
- Step 1에서는 내부 DB를 연결하지 않습니다.
- `노동법 RAG` PDF는 업로드하지 않습니다.
- 필요 정보는 API 재조회로만 채웁니다.
