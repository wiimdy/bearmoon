---
icon: hand-wave
cover: https://gitbookio.github.io/onboarding-template-images/header.png
coverY: 0
layout:
  cover:
    visible: true
    size: full
  title:
    visible: true
  description:
    visible: false
  tableOfContents:
    visible: true
  outline:
    visible: true
  pagination:
    visible: true
---

# 머릿말

이 문서는 베라체인의 메커니즘인 **PoL(Proof of Liquidity)** 시스템에서 발생할 수 있는 보안 위협 요소를 식별하고 이를 예방하기 위한 실질적인 가이드라인을 제시합니다.

베라체인 생태계는 PoL 메커니즘을 통해 새로운 경제 모델을 제시하지만, 동시에 새로운 보안 위협에 노출될 수 있습니다. 본 가이드라인은 이러한 위협으로부터 생태계를 보호하고, 개발자들이 보다 안전하고 신뢰할 수 있는 dApp을 구축하는 데 필요한 지침과 **모범 사례를 제공**하는 것을 목표로 합니다.

또한, 베라체인의 안전한 운영과 생태계의 지속 가능한 성장을 위해 체인 운영자, dApp 빌더, 유동성 공급자, 커뮤니티 구성원 모두가 참고할 수 있도록 작성되었습니다.

저희 Bearmoon 팀은 프로토콜에 대한 코드 분석과 PoL 구조에 대한 심층 리서치를 통해 **보안 가이드라인** 문서를 작성했습니다. 이 문서를 통해 베라체인의 코어 컨트랙트와 주요한 dApp 프로토콜에 실질적이고 적용 가능한 보안 지침을 제공하여 **베라체인이 더욱 안전하고 신뢰받는 네트워크로 발전하는 데 기여**하고자 합니다.



### Impact Classification

<table><thead><tr><th width="92.0078125" align="center">위협</th><th align="center">Infomational</th><th align="center">Low</th><th align="center">Medium</th><th width="179.13671875" align="center">High</th></tr></thead><tbody><tr><td align="center">분류</td><td align="center">보안상 직접적인 영향은 없으나, 참고 사항</td><td align="center">시스템에 미치는 영향이 미미한 수준</td><td align="center">특정 기능 또는 일부 자산에 영향을 줄 수 있는 수준</td><td align="center">시스템 전체에 중대한 영향을 끼칠 수 있는 치명적 취약점</td></tr></tbody></table>

