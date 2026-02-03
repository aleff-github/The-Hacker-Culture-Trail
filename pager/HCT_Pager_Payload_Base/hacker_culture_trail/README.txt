The Hacker Culture Trail - Hak5 WiFi Pineapple Pager payload base

Install:
1) Copy this whole directory to your Pager:
   /root/payloads/user/games/hacker_culture_trail/

2) Ensure payload.sh is executable:
   chmod +x /root/payloads/user/games/hacker_culture_trail/payload.sh

Files:
- payload.sh              (game runtime, pure bash + Pager DuckyScript commands)
- story/story.tsv         (graph: node_id<TAB>choice1_target<TAB>choice2_target)
- locales/it.lang         (strings: key=value, supports \n)
- locales/en.lang         (UI-only example)
- tools/compile_twee.py   (convert your SugarCube .twee into story.tsv + locale)

Notes:
- This payload does NOT use any WiFi/Pineapple offensive functions. It's a text adventure runner.
- The runtime uses PAYLOAD_SET_CONFIG / GET to persist language and progress across reboots/upgrades.
