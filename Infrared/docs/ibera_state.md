```mermaid
iBeraStateDiagram
    [*] --> ContractDeployment: Deploy Protocol
    
    state "Protocol Initialization" as Init {
        ContractDeployment: Deploy Core Contracts (Gov)
        ContractInitialize: Initialize with Admin/Roles
        SetupReferences: Set Contract References
        AdminSetup: Setup RBAC Permissions
        InitialMint: Initial Safety Mint
        
        ContractDeployment --> ContractInitialize
        ContractInitialize --> SetupReferences
        SetupReferences --> AdminSetup
        AdminSetup --> InitialMint
    }
    
    Init --> InfraredBERA: Protocol Activated

    state "InfraredBERA (Main Entry Point)" as InfraredBERA {
        Ready: Base state
        state "Core Functions" as CoreFunctions {
            Mint: User calls mint()
            Burn: User calls burn()
            Compound: Anyone calls compound()
        }
        SignatureStore: setDepositSignature() - Gov only
    }

    state "Permissionless Operations" as PublicOps {
        state "FeeReceiver Flow" as FeeFlow {
            CollectFees: InfraredBERAFeeReceiver receives tips & MEV
            Distribution: Calculate protocol & shareholder fees
            Sweep: InfraredBERAFeeReceiver.sweep()
            
            CollectFees --> Distribution: On block rewards
            Distribution --> Sweep: Anyone can trigger
        }
    }

    state "Permissioned Operations" as PermissionedOps {
        state "Deposit Handler" as StakingFlow {
            QueueDeposit: InfraredBERADepositor.queue()
            ExecuteDeposit: InfraredBERADepositor.execute()
            ValidatorCheck: InfraredBERA.validator()
            BeaconDeposit: BeaconDeposit.deposit()
            
            QueueDeposit --> ExecuteDeposit: Keeper + fee escrow
            ExecuteDeposit --> ValidatorCheck: Check gov signature
            ValidatorCheck --> BeaconDeposit: Balance validation
        }

        state "Withdrawal Handler" as WithdrawFlow {
            QueueWithdraw: InfraredBERAWithdrawor.queue()
            ExecuteWithdraw: InfraredBERAWithdrawor.execute()
            ProcessWithdraw: InfraredBERAWithdrawor.process()
            ClaimQueue: InfraredBERAClaimor.queue()
            UserClaim: InfraredBERAClaimor.sweep()
            
            QueueWithdraw --> ExecuteWithdraw: Keeper only
            ExecuteWithdraw --> ProcessWithdraw: Balance check
            ProcessWithdraw --> ClaimQueue: Amount verify
            ClaimQueue --> UserClaim: Receiver verify
        }

        state "Rebalance Handler" as RebalanceFlow {
            QueueRebalance: InfraredBERAWithdrawor.queue()
            ExecuteRebalance: InfraredBERAWithdrawor.execute()
            ProcessRebalance: InfraredBERAWithdrawor.process()
            ReDepositFunds: InfraredBERADepositor.queue()
            
            QueueRebalance --> ExecuteRebalance: Keeper only
            ExecuteRebalance --> ProcessRebalance: Balance check
            ProcessRebalance --> ReDepositFunds: Amount verify
        }
    }

    InfraredBERA --> StakingFlow: Mint triggers deposit flow
    InfraredBERA --> WithdrawFlow: Burn triggers withdraw flow
    InfraredBERA --> RebalanceFlow: Keeper initiates rebalance
    InfraredBERA --> FeeFlow: compound() triggers sweep
    
    FeeFlow --> StakingFlow: Swept fees auto-compound
    StakingFlow --> InfraredBERA: Update stakes
    WithdrawFlow --> InfraredBERA: Update balances
    RebalanceFlow --> InfraredBERA: Update state

    state "Validator Management" as ValidatorMgmt {
        state "Infrared Contract" as InfraredContract {
            ValidatorSet: Infrared.infraredValidators()
            ManageValidators: Governance only operations
            ValidatorChecks: Signature validation
            
            ValidatorSet --> ManageValidators: Gov check
            ManageValidators --> ValidatorChecks: Sig verify
        }
    }
    
    ValidatorMgmt --> InfraredBERA: Validator verification

    note right of InfraredBERA
        Main contract that:
        - Handles user entry points
        - Orchestrates operations
        - Maintains protocol state
        - Tracks validator stakes
        - Stores validator signatures (Gov controlled)
    end note

    note right of PublicOps
        Permissionless Operations:
        - Fee collection is automatic
        - Anyone can call sweep()
        - Compounds through deposit flow
        - No special permissions needed
    end note

    note right of PermissionedOps
        Requires specific permissions:
        - Deposit operations (Keeper)
        - Withdrawal operations (Keeper)
        - Claim operations (User)
        First deposit requires valid gov signature
    end note
```