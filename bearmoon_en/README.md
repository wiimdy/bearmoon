---
icon: hand-wave
---

# Introduction

<figure><img src=".gitbook/assets/image (8).png" alt=""><figcaption></figcaption></figure>

***

This document provides a comprehensive security analysis of Berachain's Proof of Liquidity (PoL) system, identifying potential threats and presenting practical guidelines to mitigate them.

The innovative economic model of the Berachain ecosystem, centered around its PoL mechanism, introduces powerful new functionalities but also exposes novel attack surfaces. This document specifically addresses security threats ranging from smart contract-level vulnerabilities (e.g., re-entrancy, Inflation attack) to complex economic exploits targeting the BGT issuance and governance problem.

To counter these risks, we present a set of practical guidelines. These are not just abstract principles but include actionable secure coding patterns for Solidity, architectural recommendations for robust dApp integration with PoL, and operational security checklists for pre-launch audits.

This guide is designed to be a valuable resource for all key participants in the Berachain ecosystem:

* For dApp Builders: You will find essential best practices and design patterns to develop secure applications that safely interact with the PoL system, thereby protecting your users and protocol.
* For Chain Operators: This analysis provides a framework for understanding and mitigating systemic risks to the core protocol, contributing to the overall stability and security of the chain.
* For Liquidity Providers & Users: You will be better equipped to assess the security posture of dApps, understand the risks associated with providing liquidity, and make more informed decisions to protect your assets.
* For Community Members: This document provides the necessary context to evaluate security-related governance proposals and contribute to building a more resilient and secure ecosystem.

Our Bearmoon team has created this security guideline document through code analysis of the protocol and in-depth research on the PoL structure. Through this document, we aim to provide practical and applicable security guidelines for Berachain's core contracts and major dApp protocols, contributing to Berachain's development as a more secure and trusted network.
