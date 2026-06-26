# 사내 복지포인트 지갑 서비스

Nginx와 Redis를 활용해 단일 GCP VM 안에서 여러 프론트엔드와 백엔드 API를 분산 실행하는 실습 프로젝트입니다. 원본 mobile-bank 예제를 사내 복지포인트 도메인으로 자기화했습니다.

## 1. 분산 아키텍처 및 자기화 요약

- 선정 주제: Nginx/Redis 기반 사내 복지포인트 지갑 서비스
- Nginx 3000: 대표 접속 포트, PC/모바일/포인트 이용 화면/API 라우팅
- Next Admin 3001: PC 복지포인트 운영자 콘솔
- Next Mobile View 3002: 모바일 포인트 지갑 조회 화면
- Next Mobile Action 3003: 모바일 포인트 충전/사용/선물 화면
- Spring Boot API 3004: 인증/지갑/포인트 이용/운영자 API
- MariaDB 3306: 사용자, 지갑, 포인트 이용내역 저장
- Redis 6379: JWT 세션 검증, 지갑 캐시, 감사 로그, 최근 선물 대상 저장
- Cloudflared: `localhost:3000`만 외부 공개

## 2. 용어 치환 기록

- 은행 계좌(Account) -> 포인트 지갑
- 계좌 잔액(balance) -> 보유 포인트
- 입금(deposit) -> 포인트 충전
- 출금(withdraw) -> 포인트 사용
- 송금(transfer) -> 포인트 선물
- 거래내역 -> 포인트 이용내역

Java 파일명, 클래스명, API 주소는 예제 안정성을 위해 유지하고, 화면 문구와 테스트 데이터 중심으로 도메인을 전환했습니다.

## 3. 분산 데이터 흐름 및 캐시 검증

- PC 브라우저가 `/`로 접근하면 Nginx가 `frontend-admin:3001`로 전달합니다.
- 모바일 브라우저가 `/`로 접근하면 User-Agent 조건에 따라 `frontend-mobile-view:3002`로 전달합니다.
- `/action` 경로는 모바일 포인트 이용 화면인 `frontend-mobile-action:3003`으로 전달합니다.
- `/api/*` 요청은 Spring Boot API 서버 `backend-spring-api:3004`로 전달합니다.
- 로그인 시 Spring Boot가 Redis에 `auth:session:*` 키를 만들고, JWT에는 해당 sessionId가 포함됩니다.
- 인증 요청 시 `JwtAuthenticationFilter`가 JWT를 파싱한 뒤 Redis에 세션 키가 존재하는지 확인합니다.
- 지갑 조회 결과는 Redis `cache:account:*`에 저장되고, 충전/사용/선물 후에는 해당 캐시가 삭제되어 최신 데이터가 다시 조회됩니다.

## 4. 커스텀 비즈니스 규칙

`BankService.java`의 포인트 사용 로직에 사내 복지포인트 정책을 반영합니다.

```java
if (r.amount().compareTo(new BigDecimal("1000")) < 0) {
    throw new IllegalArgumentException("최소 1,000P 이상만 사용할 수 있습니다");
}
```

## 5. 트러블슈팅 기록

- 문제: `/action` 경로로 접속했을 때 모바일 포인트 이용 화면의 정적 파일과 페이지 라우팅이 깨질 수 있었다.
- 원인: `frontend-mobile-action`은 Next.js `basePath=/action`을 사용하므로, Nginx에서 `/action` prefix를 제거하면 Next.js가 필요한 경로를 찾지 못한다.
- 해결: Nginx 설정에서 `/action`과 `/action/` 요청을 3003 포트로 전달하되, `/action` prefix를 제거하지 않고 그대로 proxy_pass 하도록 구성했다.

- 문제: 포인트를 충전/사용한 직후에도 지갑 조회 화면에 이전 잔액이 잠시 그대로 노출되는 데이터 불일치가 발생했다.
- 원인: 백엔드 `BankService.account()`가 `cache:account:{userId}`(TTL 30초) Redis 캐시를 먼저 읽는데, 잔액 변경 후 이 캐시를 지우지 않으면 TTL이 만료될 때까지 옛 값이 응답되었다.
- 해결: `deposit/withdraw/transfer/multiTransfer` 트랜잭션 종료 시점에 `redis.evictAccount(userId)`로 해당 캐시를 즉시 무효화(Eviction)하고, 프론트는 React Query의 `invalidateQueries`로 재조회하도록 연동해 변경 즉시 최신 잔액이 반영되게 했다. (실측: 조회 시 `cache:account:2` 생성 → 충전 후 키 삭제 확인)
