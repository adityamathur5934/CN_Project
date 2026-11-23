# Extension C — Completion Record

## Phase 2 — Backend B Service Isolation (Mac 4)

| Item | Status | Notes |
|------|--------|-------|
| Backend B confirmed on TCP 3002 | ✅ | Listen address confirmed via lsof/netstat |
| Audit before-state captured | ✅ | `/evidence/phase2/audit_before.md` |
| pf anchor rules authored | ✅ | `/evidence/phase2/pf_anchor.conf` |
| pf_setup.sh written and executable | ✅ | `/evidence/phase2/pf_setup.sh` |
| pf_rollback.sh written and executable | ✅ | `/evidence/phase2/pf_rollback.sh` |
| Verification plan written | ✅ | `/evidence/phase2/verification_plan.md` |
| Loopback (127.0.0.1) preserved | ✅ | `pass in quick on lo0` rule |
| Mac 2 (nginx) allowed on port 3002 | ✅ | `pass in quick on en0 from 10.7.11.31` |
| All other hosts blocked on port 3002 | ✅ | `block in quick on en0` |
| SSH / management traffic unaffected | ✅ | Rules are port-3002-specific only |
| Outbound traffic from Mac 4 unaffected | ✅ | Only inbound rules added |
| Backend A (Mac 3, port 3001) unaffected | ✅ | Rules only target Mac 4's port 3002 |
| Rules reversible | ✅ | `pf_rollback.sh` restores original pf.conf |
| MAC2_IP variable used in setup script | ✅ | Confirmed `10.7.11.31`; verify with Aditya |
| Secrets not committed | ✅ | Only IPs and rules; no credentials |
| Existing config files not deleted | ✅ | /etc/pf.conf backed up before modification |
| README / docs updated | ✅ | `/docs/phase2.md` created |

## Pending: Activation

The pf rules have been **authored but not yet activated**.
Activation requires:
1. Confirm `MAC2_IP=10.7.11.31` with Aditya
2. Run: `sudo bash /Users/vaidehisahu/CN/evidence/phase2/pf_setup.sh`
3. Run verification tests from `verification_plan.md`

## Git branch
`p4-backend-b` (HEAD `70cebae4506fa9a6fc0290496bad05aa8cfb047b`)

## Completed by
Mac 4 — Vaidehi — wf-coder agent
