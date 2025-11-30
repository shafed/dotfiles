---
limit: 100
mapWithTag: false
icon: presentation
tagNames: 
filesPaths:
  - projects
bookmarksGroups: 
excludes: 
extends: 
savedViews:
  - name: _➡ default
    children: []
    sorters: []
    filters:
      - id: project____file
        name: file
        query: ""
        customFilter: ""
      - id: project____tags
        name: tags
        query: ""
        customFilter: ""
      - id: project____aliases
        name: aliases
        query: ""
        customFilter: ""
      - id: project____status
        name: status
        query: ""
        customFilter: ""
      - id: project____category
        name: category
        query: ""
        customFilter: ""
      - id: project____start
        name: start
        query: ""
        customFilter: ""
      - id: project____end
        name: end
        query: ""
        customFilter: ""
    columns:
      - id: project____file
        name: file
        hidden: false
        position: 0
      - id: project____tags
        name: tags
        hidden: true
        position: 2
      - id: project____aliases
        name: aliases
        hidden: true
        position: 1
      - id: project____status
        name: status
        hidden: false
        position: 2
      - id: project____category
        name: category
        hidden: false
        position: 1
      - id: project____start
        name: start
        hidden: false
        position: 3
      - id: project____end
        name: end
        hidden: false
        position: 4
  - name: ⬛ drop
    children: []
    sorters: []
    filters:
      - id: project____file
        name: file
        query: ""
        customFilter: ""
      - id: project____tags
        name: tags
        query: ""
        customFilter: ""
      - id: project____aliases
        name: aliases
        query: ""
        customFilter: ""
      - id: project____status
        name: status
        query: drop
        customFilter: ""
      - id: project____category
        name: category
        query: ""
        customFilter: ""
      - id: project____start
        name: start
        query: ""
        customFilter: ""
      - id: project____end
        name: end
        query: ""
        customFilter: ""
    columns:
      - id: project____file
        name: file
        hidden: false
        position: 0
      - id: project____tags
        name: tags
        hidden: true
        position: 2
      - id: project____aliases
        name: aliases
        hidden: true
        position: 1
      - id: project____status
        name: status
        hidden: true
        position: 2
      - id: project____category
        name: category
        hidden: false
        position: 1
      - id: project____start
        name: start
        hidden: false
        position: 3
      - id: project____end
        name: end
        hidden: false
        position: 4
  - name: 🟥 todo
    children: []
    sorters: []
    filters:
      - id: project____file
        name: file
        query: ""
        customFilter: ""
      - id: project____tags
        name: tags
        query: ""
        customFilter: ""
      - id: project____aliases
        name: aliases
        query: ""
        customFilter: ""
      - id: project____status
        name: status
        query: todo
        customFilter: ""
      - id: project____category
        name: category
        query: ""
        customFilter: ""
      - id: project____start
        name: start
        query: ""
        customFilter: ""
      - id: project____end
        name: end
        query: ""
        customFilter: ""
    columns:
      - id: project____file
        name: file
        hidden: false
        position: 0
      - id: project____tags
        name: tags
        hidden: true
        position: 2
      - id: project____aliases
        name: aliases
        hidden: true
        position: 1
      - id: project____status
        name: status
        hidden: true
        position: 2
      - id: project____category
        name: category
        hidden: false
        position: 1
      - id: project____start
        name: start
        hidden: false
        position: 3
      - id: project____end
        name: end
        hidden: false
        position: 4
  - name: 🟦 wip
    children: []
    sorters: []
    filters:
      - id: project____file
        name: file
        query: ""
        customFilter: ""
      - id: project____tags
        name: tags
        query: ""
        customFilter: ""
      - id: project____aliases
        name: aliases
        query: ""
        customFilter: ""
      - id: project____status
        name: status
        query: wip
        customFilter: ""
      - id: project____category
        name: category
        query: ""
        customFilter: ""
      - id: project____start
        name: start
        query: ""
        customFilter: ""
      - id: project____end
        name: end
        query: ""
        customFilter: ""
    columns:
      - id: project____file
        name: file
        hidden: false
        position: 0
      - id: project____tags
        name: tags
        hidden: true
        position: 1
      - id: project____aliases
        name: aliases
        hidden: true
        position: 2
      - id: project____status
        name: status
        hidden: true
        position: 1
      - id: project____category
        name: category
        hidden: false
        position: 2
      - id: project____start
        name: start
        hidden: false
        position: 3
      - id: project____end
        name: end
        hidden: false
        position: 4
  - name: 🟩 done
    children: []
    sorters: []
    filters:
      - id: project____file
        name: file
        query: ""
        customFilter: ""
      - id: project____tags
        name: tags
        query: ""
        customFilter: ""
      - id: project____aliases
        name: aliases
        query: ""
        customFilter: ""
      - id: project____status
        name: status
        query: done
        customFilter: ""
      - id: project____category
        name: category
        query: ""
        customFilter: ""
      - id: project____start
        name: start
        query: ""
        customFilter: ""
      - id: project____end
        name: end
        query: ""
        customFilter: ""
    columns:
      - id: project____file
        name: file
        hidden: false
        position: 0
      - id: project____tags
        name: tags
        hidden: true
        position: 1
      - id: project____aliases
        name: aliases
        hidden: true
        position: 2
      - id: project____status
        name: status
        hidden: true
        position: 1
      - id: project____category
        name: category
        hidden: false
        position: 2
      - id: project____start
        name: start
        hidden: false
        position: 3
      - id: project____end
        name: end
        hidden: false
        position: 4
favoriteView: _➡ default
fieldsOrder:
  - c5jHEw
  - H5sr6E
  - AjLHzm
  - 0l7jyG
  - 3oZi1z
  - z8t57Q
version: "2.52"
fields:
  - name: status
    type: Select
    options:
      sourceType: ValuesList
      valuesList:
        "1": todo
        "2": wip
        "3": done
        "4": drop
    path: ""
    id: AjLHzm
  - name: category
    type: MultiFile
    options:
      dvQueryString: dv.pages("#system/category")
    path: ""
    id: 0l7jyG
  - name: start
    type: Date
    options:
      dateShiftInterval: 1 day
      dateFormat: YYYY-MM-DD
      defaultInsertAsLink: false
      linkPath: ""
    path: ""
    id: 3oZi1z
  - name: end
    type: Date
    options:
      dateShiftInterval: 1 day
      dateFormat: YYYY-MM-DD
      defaultInsertAsLink: false
      linkPath: ""
    path: ""
    id: z8t57Q
  - name: tags
    type: Multi
    options:
      sourceType: ValuesList
      valuesList:
        "1": project/single
    path: ""
    id: c5jHEw
  - name: aliases
    type: YAML
    options: {}
    path: ""
    id: H5sr6E
---
