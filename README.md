```
    ____            _           ______      __            
   / __ \___  _____(_)___ _____/_  __/___  / /_____  ____ 
  / / / / _ \/ ___/ / __ `/ __ \/ / / __ \/ //_/ _ \/ __ \
 / /_/ /  __(__  ) / /_/ / / / / / / /_/ / ,< /  __/ / / /
/_____/\___/____/_/\__, /_/ /_/_/  \____/_/|_|\___/_/ /_/ 
                  /____/                                   

   ______                           __            
  / ____/__  ____  ___  _________ _/ /_____  _____
 / / __/ _ \/ __ \/ _ \/ ___/ __ `/ __/ __ \/ ___/
/ /_/ /  __/ / / /  __/ /  / /_/ / /_/ /_/ / /    
\____/\___/_/ /_/\___/_/   \__,_/\__/\____/_/     
```

# DesignTokenGenerator
[![CI](https://github.com/Jranco/DesignTokenGenerator/actions/workflows/ci.yml/badge.svg)](https://github.com/Jranco/DesignTokenGenerator/actions/workflows/ci.yml)

Parses design tokens from a JSON and generates respective code in various languages

```
                        ┌─────────────────────────┐
                        │   DesignTokenGenerator  │
  ┌──────────────┐      │                         │      ┌─────────────────────┐
  │  Figma JSON  │─────▶│  ┌───────────────────┐  │─────▶│  /xcode             │
  │              │      │  │  Variable Colors  │  │      │  ├─ .xcassets        │
  │  variables   │      │  │  Style Colors     │  │      │  ├─ ColorTokens.swift│
  │  styles      │      │  │  Text Styles      │  │      │  ├─ DesignVars.swift │
  │  collections │      │  │  Design Variables │  │      │  └─ FontTokens.swift │
  └──────────────┘      │  └───────────────────┘  │      ├─────────────────────┤
                        │                         │      │  /web               │
                        │  --platform xcode        │─────▶│  ├─ ColorTokens.css │
                        │  --platform web          │      │  ├─ DesignVars.css  │
                        │  --platform android      │      │  └─ FontTokens.css  │
                        │                         │      ├─────────────────────┤
                        │  [collections|modes]     │      │  /android           │
                        └─────────────────────────┘      │  └─ coming soon     │
                                                          └─────────────────────┘
```
