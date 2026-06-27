# Triage Labels

Label strings used by the `triage` skill's state machine.

| Role | Label string |
|---|---|
| Needs evaluation | `needs-triage` |
| Waiting on reporter | `needs-info` |
| AFK-ready | `ready-for-agent` |
| Human-ready | `ready-for-human` |
| Won't action | `wontfix` |

Create them in GitHub once with:

```bash
gh label create needs-triage --color "#e4e669" --description "Maintainer needs to evaluate"
gh label create needs-info --color "#d93f0b" --description "Waiting on more info from reporter"
gh label create ready-for-agent --color "#0075ca" --description "Fully specified, AFK-agent ready"
gh label create ready-for-human --color "#cfd3d7" --description "Ready for human implementation"
gh label create wontfix --color "#ffffff" --description "Will not be actioned"
```
