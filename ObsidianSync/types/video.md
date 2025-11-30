---
limit: 100
mapWithTag: true
icon: video
tagNames:
  - source/video
filesPaths: 
bookmarksGroups: 
excludes: 
extends: source
savedViews:
  - name: _➡ default
    children: []
    sorters:
      - id: video____status
        name: status
        direction: asc
        priority: 1
        customOrder:
          - wip
          - todo
          - done
          - drop
    filters:
      - id: video____file
        name: file
        query: ""
        customFilter: ""
      - id: video____status
        name: status
        query: ""
        customFilter: ""
      - id: video____category
        name: category
        query: ""
        customFilter: ""
      - id: video____creator
        name: creator
        query: ""
        customFilter: ""
      - id: video____url
        name: url
        query: ""
        customFilter: ""
      - id: video____tags
        name: tags
        query: ""
        customFilter: ""
      - id: video____aliases
        name: aliases
        query: ""
        customFilter: ""
    columns:
      - id: video____file
        name: file
        hidden: false
        position: 0
      - id: video____status
        name: status
        hidden: false
        position: 1
      - id: video____category
        name: category
        hidden: false
        position: 2
      - id: video____creator
        name: creator
        hidden: false
        position: 3
      - id: video____url
        name: url
        hidden: false
        position: 4
      - id: video____tags
        name: tags
        hidden: true
        position: 5
      - id: video____aliases
        name: aliases
        hidden: true
        position: 6
favoriteView: _➡ default
fieldsOrder: []
version: "2.8"
---

```mdm
type: video
view: _➡ default
```