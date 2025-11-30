---
limit: 100
mapWithTag: true
icon: map
tagNames:
  - system/category
filesPaths: 
bookmarksGroups: 
excludes: 
extends: 
savedViews:
  - name: _➡ default
    children: []
    sorters: []
    filters:
      - id: category____file
        name: file
        query: ""
        customFilter: ""
      - id: category____tags
        name: tags
        query: ""
        customFilter: ""
      - id: category____aliases
        name: aliases
        query: ""
        customFilter: ""
    columns:
      - id: category____file
        name: file
        hidden: false
        position: 0
      - id: category____tags
        name: tags
        hidden: true
        position: 1
      - id: category____aliases
        name: aliases
        hidden: true
        position: 2
favoriteView: _➡ default
fieldsOrder:
  - B2Vpoo
  - Tucuqh
version: "2.22"
fields:
  - name: tags
    type: Multi
    options:
      sourceType: ValuesList
      valuesList:
        "1": system/category
    path: ""
    id: B2Vpoo
  - name: aliases
    type: YAML
    options: {}
    path: ""
    id: Tucuqh
---
