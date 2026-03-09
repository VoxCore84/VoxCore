import json, re, os, sys, io
from collections import Counter, defaultdict

# Force UTF-8 output
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

files = [
    ('troubleshooting', 'C:/Users/atayl/VoxCore/doc/discord_export_troubleshooting.json'),
    ('bugreport', 'C:/Users/atayl/VoxCore/doc/discord_export_bugreport.json'),
    ('tww', 'C:/Users/atayl/VoxCore/doc/discord_export_tww.json'),
    ('draconicwow', 'C:/Users/atayl/VoxCore/doc/discord_export_draconicwow.json'),
    ('gettingstarted', 'C:/Users/atayl/VoxCore/doc/discord_export_gettingstarted.json'),
    ('customoptions', 'C:/Users/atayl/VoxCore/doc/discord_export_customoptions.json'),
    ('tools', 'C:/Users/atayl/VoxCore/doc/discord_export_tools.json'),
    ('sqlfixes', 'C:/Users/atayl/VoxCore/doc/discord_export_sqlfixes.json'),
]

# Category patterns - ordered by specificity (most specific first)
categories = [
    # Installation & Setup
    ("Arctium Launcher Issues", re.compile(r'arctium|launcher\s*(crash|error|not\s*work|issue|problem|won.?t|can.?t|bug|broken|fail)', re.I)),
    ("Client Version / Build Mismatch", re.compile(r'client\s*version|build\s*\d{4,}|wrong\s*(?:version|build|client)|version\s*mismatch|client\s*(?:update|patch)|which\s*(?:version|build|client)|what\s*(?:version|build|client)|compatible\s*(?:version|client)|wow\s*version|retail\s*(?:version|build|client)', re.I)),
    ("Cannot Connect to Server", re.compile(r'can.?t\s*connect|unable\s*to\s*connect|connection\s*(?:refused|failed|error|issue|problem|lost|timeout)|disconnec|unable\s*to\s*log\s*in|can.?t\s*log\s*in|login\s*(?:fail|error|issue)|realmlist|BNet|battle\.?net\s*(?:server|error|issue|fail)|auth\s*(?:server|fail|error)|stuck\s*(?:at|on)\s*(?:connect|login|loading|realm)', re.I)),
    ("How to Install / Setup Server", re.compile(r'how\s*(?:to|do\s*[iI])\s*(?:install|setup|set\s*up|get\s*start|compil|build|run\s*(?:the|a|my)\s*server|start\s*(?:the|a|my)\s*server|configure)|install\s*guide|setup\s*guide|getting\s*started|first\s*time\s*(?:setting|install|build|compil)|new\s*(?:to\s*(?:this|trinity|draconic))|step\s*by\s*step|tutorial|where\s*(?:to|do)\s*(?:start|begin)|what\s*do\s*i\s*need\s*to', re.I)),

    # Build & Compile
    ("OpenSSL Build Errors", re.compile(r'openssl|ssl\s*(?:error|issue|problem|not\s*found|missing|link|lib)', re.I)),
    ("CMake / Configuration Errors", re.compile(r'cmake\s*(?:error|fail|issue|problem|not|can|warning)|cmake.*(?:error|fail)|(?:error|fail|issue|problem).*cmake|generator\s*(?:error|not)|preset\s*(?:error|not|fail)|msbuild\s*(?:error|fail)', re.I)),
    ("Compile / Build Errors (General)", re.compile(r'compil(?:e|ing|ation)\s*(?:error|fail|issue|problem)|build\s*(?:error|fail|issue|problem)|linker?\s*error|LNK\d+|C\d{4,5}|ninja\s*(?:error|fail)|fatal\s*error|cannot\s*(?:open|find)\s*(?:file|include|source)|unresolved\s*(?:external|symbol)|undefined\s*(?:reference|symbol)|build\s*(?:broke|broken)', re.I)),
    ("Boost / Dependency Issues", re.compile(r'boost\s*(?:error|not\s*found|missing|issue|problem|install|version)|(?:dependency|dependencies)\s*(?:error|not\s*found|missing|issue|problem)', re.I)),
    ("Visual Studio / MSVC Issues", re.compile(r'visual\s*studio\s*(?:error|issue|problem|version|install|202[0-9])|msvc|cl\.exe|vcpkg', re.I)),

    # Database
    ("Database Connection / Setup Issues", re.compile(r'(?:mysql|mariadb|database|db)\s*(?:error|issue|problem|fail|can.?t|unable|connect|setup|install|missing|not\s*(?:found|work|connect|start|run))|access\s*denied.*(?:mysql|database)|table\s*(?:doesn.?t\s*exist|not\s*found|missing)|column\s*(?:doesn.?t\s*exist|not\s*found|unknown)', re.I)),
    ("Database Update / Migration Questions", re.compile(r'(?:database|db)\s*(?:update|migrat|upgrad|merge|import)|sql\s*(?:update|file|script|import|apply)|pending\s*(?:update|sql)|update\s*(?:sql|database|db|schema)|TDB\s*(?:full|import|update|file|download)|full\s*(?:database|db)\s*(?:download|import|file)', re.I)),
    ("Hotfix / DB2 / DBC Data Issues", re.compile(r'hotfix\s*(?:error|issue|problem|not|missing|wrong|table|data|import|apply)|db2\s*(?:error|issue|not|missing)|dbc\s*(?:error|issue|not|missing|data)|casc\s*(?:error|issue|not)|listfile', re.I)),

    # Server Runtime
    ("Server Crash / Segfault", re.compile(r'(?:server|world\s*server|worldserver|auth\s*server)\s*(?:crash|segfault|seg\s*fault|assertion|abort|terminat|died|stopped|shut\s*down)|crash(?:es|ed|ing)\s*(?:when|after|on|at|during|every|my|the|server|world)|segfault|SIGSEGV|access\s*violation|unhandled\s*exception|stack\s*trace|core\s*dump|server\s*closes\s*(?:when|after|on)', re.I)),
    ("Server Startup Issues", re.compile(r'(?:server|worldserver)\s*(?:won.?t|can.?t|not|unable|fail)\s*(?:start|launch|run|load|boot)|startup\s*(?:error|fail|issue|problem)|server\s*(?:takes|slow|hang|freeze)\s*(?:long|forever|to\s*start)|worldserver\s*(?:closes|exit|quit)\s*(?:immedia|right\s*away|instant)', re.I)),
    ("Config / worldserver.conf", re.compile(r'(?:worldserver|authserver|bnetserver)\.conf|config\s*(?:file|option|setting)\s*(?:error|issue|problem|not|missing|where|how)', re.I)),

    # Game Content Issues
    ("Quest Issues / Broken Quests", re.compile(r'quest\s*(?:(?:not|doesn.?t|can.?t|won.?t|isn.?t)\s*(?:work|complet|start|finish|turn|accept|track|show|appear|update|progress)|bug|broken|stuck|issue|problem|missing|error|fail)|broken\s*quest|quest\s*(?:chain|line)\s*(?:broken|stuck|bug)|can.?t\s*(?:accept|complete|finish|start|turn\s*in)\s*(?:the\s*)?quest', re.I)),
    ("NPC Missing / Not Spawned / Wrong", re.compile(r'npc\s*(?:not\s*(?:spawn|there|exist|show|appear|found)|missing|gone|disappear)|(?:creature|mob|vendor|trainer|innkeeper|flightmaster|flight\s*master)\s*(?:not\s*(?:spawn|there|show|appear|found)|missing|gone)|missing\s*(?:npc|creature|mob|vendor|trainer)|can.?t\s*find\s*(?:npc|creature|vendor|trainer|the\s*npc)', re.I)),
    ("Spell / Ability / Talent Issues", re.compile(r'(?:spell|ability|talent|skill|aura|buff|debuff|proc|passive)\s*(?:not\s*(?:work|cast|function|apply|show|appear|learn|train)|broken|bug|issue|problem|missing|error|wrong|incorrect|crash)|can.?t\s*(?:cast|use|learn|train)\s*(?:spell|ability|talent|skill)|talent\s*(?:tree|spec|specialization)\s*(?:not|broken|bug|issue|wrong|missing)', re.I)),
    ("Teleport / Portal / Phasing Issues", re.compile(r'(?:portal|teleport|phase|phasing)\s*(?:not\s*(?:work|function|teleport|show|appear|load)|broken|bug|issue|problem|missing|error|wrong|stuck)|can.?t\s*(?:enter|teleport|use)\s*(?:portal|instance|dungeon|raid)|stuck\s*(?:in|at|on)\s*(?:loading|instance|phase|portal|teleport)|wrong\s*phase|phase\s*(?:issue|problem|error)|phased?\s*(?:out|wrong|different)', re.I)),
    ("Transmog / Appearance Issues", re.compile(r'transmog|transmogrif|wardrobe\s*(?:not|broken|bug|issue|error|empty|missing)', re.I)),
    ("Mount / Flying / Dragonriding Issues", re.compile(r'(?:mount|flying|fly|dragonriding|skyriding|pathfinder|dynamic\s*flight)\s*(?:not\s*(?:work|function|show|learn|available)|broken|bug|issue|problem|missing|error|can.?t)|can.?t\s*(?:mount|fly|ride|use\s*(?:mount|flying|dragonriding))|dragonrid(?:e|ing)\s*(?:not|broken|bug|issue|can.?t)', re.I)),
    ("Item / Loot / Gear Issues", re.compile(r'(?:item|loot|drop|gear|equipment|weapon|armor)\s*(?:not\s*(?:work|drop|show|appear|equip|use|exist)|broken|bug|issue|problem|missing|error|wrong|incorrect)|missing\s*(?:item|loot|drop|gear|weapon)|(?:item|loot)\s*(?:table|template)\s*(?:error|issue|not|missing|wrong)', re.I)),
    ("Map / Terrain / Visual / Extract Issues", re.compile(r'(?:map|terrain|visual|graphic|texture|model|display|minimap|world\s*map)\s*(?:not\s*(?:work|load|show|appear|render|display)|broken|bug|issue|problem|missing|error|wrong|glitch|corrupt)|(?:fall|falling)\s*(?:through|under)\s*(?:the\s*)?(?:map|ground|floor|world|terrain)|(?:vmap|mmap|vmaps|mmaps)\s*(?:not|missing|error|issue|extract|generat)|(?:extract|extractor)\s*(?:error|fail|issue|problem|not\s*(?:work|found))|mapextractor|vmapextractor|mmapgenerator', re.I)),
    ("Character / Race / Customization Issues", re.compile(r'(?:character|char)\s*(?:creation|create)\s*(?:error|issue|problem|not|fail|crash|stuck)|(?:race|races)\s*(?:not\s*(?:work|show|available|unlock)|missing|issue|error|bug)|(?:earthen|dracthyr|void\s*elf|allied\s*race|vulpera|mechagnome|dark\s*iron|highmountain|nightborne|lightforged|zandalari|kul\s*tiran|mag.?har)\s*(?:not|can.?t|won.?t|issue|error|bug|missing|broken)|allied\s*race|race\s*(?:unlock|available|select)', re.I)),
    ("Creature AI / Combat / Pathing", re.compile(r'(?:creature|mob|enemy|boss)\s*(?:ai|combat|fight|attack|aggro|evade|leash|path|walk|wander|movement|behavior)\s*(?:not|broken|bug|issue|problem|wrong|error|missing)|evade\s*(?:bug|issue|mode|loop)|(?:ai|smartai|smart\s*ai)\s*(?:not\s*(?:work|function)|broken|bug|issue|problem|wrong|error)', re.I)),
    ("Gameobject / Interaction Issues", re.compile(r'(?:gameobject|game\s*object|gob|chest|node|herb|ore|door|gate)\s*(?:not\s*(?:work|function|interact|click|open|close|spawn|show|appear)|broken|bug|issue|problem|missing|error)|can.?t\s*(?:interact|click|open|loot|gather|mine|herb|pick)\s*(?:with)?', re.I)),
    ("Instance / Dungeon / Raid Issues", re.compile(r'(?:instance|dungeon|raid|mythic|heroic|lfg|lfr|dungeon\s*finder|group\s*finder)\s*(?:not\s*(?:work|function|queue|start|enter|load|teleport)|broken|bug|issue|problem|missing|error|crash|stuck)|can.?t\s*(?:enter|queue|start|join)\s*(?:instance|dungeon|raid|mythic|heroic)', re.I)),

    # Tools & Misc
    ("Git / Source Control Issues", re.compile(r'git\s*(?:clone|pull|merge|conflict|error|issue|problem|checkout|branch|submodule|lfs|fetch|reset)|merge\s*conflict|clone\s*(?:error|fail|issue|slow|stuck)', re.I)),
    ("Linux / Docker / Non-Windows Setup", re.compile(r'(?:linux|ubuntu|debian|centos|fedora|docker|container|wsl|macos|mac\s*os)\s*(?:error|issue|problem|install|setup|build|compil|run|help|guide|support)', re.I)),
    ("Eluna / Lua Scripting Issues", re.compile(r'(?:eluna|lua)\s*(?:error|issue|problem|not\s*(?:work|function|load)|broken|bug|crash|script|question|help)', re.I)),
    ("Custom Patch / Mod Issues", re.compile(r'(?:custom|mod|patch|module)\s*(?:error|issue|problem|not\s*(?:work|function|load|compil)|broken|bug|crash|conflict|merge)|how\s*to\s*(?:add|create|make|write)\s*(?:custom|mod|patch|module|script)', re.I)),
]

all_messages = {}
all_issues = defaultdict(list)  # category -> list of (channel, author, content, timestamp)
uncategorized_issues = []

for channel_name, filepath in files:
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
    messages = data.get('messages', [])
    all_messages[channel_name] = messages

    for msg in messages:
        content = msg.get('content', '') or ''
        if not content.strip():
            continue

        author = msg.get('author', {}).get('name', 'unknown')
        timestamp = msg.get('timestamp', '')

        # Check if this message looks like an issue/question
        issue_indicators = re.compile(
            r"(?:error|crash|not\s*work|broken|help|how\s*(?:to|do)|fix|issue|bug|can't|cannot|problem|stuck|fail|wrong|missing|doesn't|don't|won't|isn't|unable|why\s*(?:is|does|do|can|won)|what\s*(?:am|should|do)|anyone\s*(?:know|else|have|had|getting|got)|does\s*(?:anyone|somebody)|having\s*(?:trouble|issue|problem|error)|getting\s*(?:error|issue|problem)|need\s*help|\?)",
            re.I
        )

        if not issue_indicators.search(content):
            continue

        matched = False
        for cat_name, cat_pattern in categories:
            if cat_pattern.search(content):
                all_issues[cat_name].append((channel_name, author, content, timestamp))
                matched = True
                break  # First match wins

        if not matched:
            uncategorized_issues.append((channel_name, author, content, timestamp))

# Print results
total_msgs = sum(len(m) for m in all_messages.values())
total_issues = sum(len(v) for v in all_issues.values()) + len(uncategorized_issues)

print(f"=== TOTAL MESSAGES: {total_msgs} ===")
print(f"=== MESSAGES WITH ISSUE INDICATORS: {total_issues} ===")
print(f"=== CATEGORIZED: {sum(len(v) for v in all_issues.values())} ===")
print(f"=== UNCATEGORIZED: {len(uncategorized_issues)} ===")
print()

# Per-channel breakdown
print("=== PER-CHANNEL BREAKDOWN ===")
for channel_name, messages in all_messages.items():
    non_empty = sum(1 for m in messages if (m.get('content', '') or '').strip())
    print(f"  {channel_name}: {len(messages)} total, {non_empty} with content")
print()

# Sort categories by count
sorted_cats = sorted(all_issues.items(), key=lambda x: len(x[1]), reverse=True)

for i, (cat_name, entries) in enumerate(sorted_cats):
    print(f"\n{'='*80}")
    print(f"#{i+1}: {cat_name} ({len(entries)} occurrences)")
    print(f"{'='*80}")
    # Show channel distribution
    chan_counts = Counter(e[0] for e in entries)
    print(f"  Channels: {dict(chan_counts)}")
    # Show up to 5 examples
    seen = set()
    count = 0
    for ch, author, content, ts in entries:
        snippet = content[:400].replace('\n', ' ').strip()
        if snippet in seen:
            continue
        seen.add(snippet)
        count += 1
        if count <= 5:
            print(f"  [{ch}] @{author} ({ts[:10]}): {snippet}")
    print()

# Print some uncategorized samples for inspection
print(f"\n{'='*80}")
print(f"UNCATEGORIZED SAMPLES (showing 30 of {len(uncategorized_issues)})")
print(f"{'='*80}")
seen = set()
count = 0
for ch, author, content, ts in uncategorized_issues:
    snippet = content[:300].replace('\n', ' ').strip()
    if snippet in seen or len(snippet) < 20:
        continue
    seen.add(snippet)
    count += 1
    if count <= 30:
        print(f"  [{ch}] @{author} ({ts[:10]}): {snippet}")
