import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: service

  readonly property string home: String(Quickshell.env("HOME") || "")
  readonly property string cacheRoot: String(Quickshell.env("XDG_CACHE_HOME") || (home + "/.cache")) + "/dots-shell"
  readonly property string cachePath: cacheRoot + "/agents.json"
  readonly property string claudeRoot: String(Quickshell.env("CLAUDE_CONFIG_DIR") || (home + "/.claude"))

  property var rows: []
  property bool refreshing: false
  property double lastUpdatedMs: 0

  property bool claudeInstalled: false
  property bool codexInstalled: false
  property bool claudeDone: true
  property bool codexDone: true
  property var claudeFresh: ({ plan: "", limits: [] })
  property var codexFresh: ({ plan: "", limits: [] })
  property string claudePlan: ""
  property string pendingClaudeToken: ""
  property var codexAccount: ({})
  property var codexRateLimits: ({})

  function cachedById() {
    var result = ({})
    var current = rows || []
    for (var i = 0; i < current.length; i++) {
      var item = current[i]
      if (item && item.id) result[String(item.id)] = item
    }
    return result
  }

  function loadCache() {
    try {
      var parsed = JSON.parse(cacheFile.text())
      if (Array.isArray(parsed)) rows = parsed
    } catch (e) {}
  }

  function saveCache() {
    cacheFile.setText(JSON.stringify(rows || []))
  }

  function clamp01(value) {
    var number = Number(value)
    if (isNaN(number)) return 0
    return Math.max(0, Math.min(1, number))
  }

  function buildRow(agentId, name, installed, fresh, previous) {
    fresh = fresh || ({})
    previous = previous || ({})
    var freshLimits = Array.isArray(fresh.limits) ? fresh.limits : []
    var oldLimits = Array.isArray(previous.limits) ? previous.limits : []
    var stale = freshLimits.length === 0 && oldLimits.length > 0
    return {
      id: agentId,
      name: name,
      installed: !!installed,
      plan: String(fresh.plan || previous.plan || ""),
      limits: freshLimits.length > 0 ? freshLimits : oldLimits,
      stale: stale
    }
  }

  function refresh() {
    if (refreshing) return
    refreshing = true
    claudeDone = false
    codexDone = false
    claudeFresh = ({ plan: "", limits: [] })
    codexFresh = ({ plan: "", limits: [] })
    codexAccount = ({})
    codexRateLimits = ({})
    if (!probeProc.running) {
      probeTimeout.restart()
      probeProc.running = true
    }
  }

  function parseProbe(text) {
    probeTimeout.stop()
    claudeInstalled = false
    codexInstalled = false
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].split("=")
      if (parts.length !== 2) continue
      if (parts[0] === "claude") claudeInstalled = parts[1] === "1"
      if (parts[0] === "codex") codexInstalled = parts[1] === "1"
    }
    refreshClaude()
    if (codexInstalled) startCodex()
    else finishCodex()
  }

  function claudeCredentials() {
    try {
      var payload = JSON.parse(credentialsFile.text())
      return payload && payload.claudeAiOauth ? payload.claudeAiOauth : ({})
    } catch (e) {
      return ({})
    }
  }

  function claudePlanFrom(login) {
    var tier = String(login && login.rateLimitTier ? login.rateLimitTier : "")
    var subscription = String(login && login.subscriptionType ? login.subscriptionType : "")
    var match = /max_(\d+x)/i.exec(tier)
    if (match && match.length > 1) return "Max " + match[1]
    return subscription ? subscription.charAt(0).toUpperCase() + subscription.slice(1) : ""
  }

  function refreshClaude() {
    var login = claudeCredentials()
    claudePlan = claudePlanFrom(login)
    var token = String(login && login.accessToken ? login.accessToken : "")
    if (!token) {
      finishClaude({ plan: claudePlan, limits: [] })
      return
    }

    pendingClaudeToken = token
    claudeTimeout.restart()
    claudeProc.running = true
  }

  function handleClaudeStarted() {
    claudeProc.write(pendingClaudeToken + "\n")
    pendingClaudeToken = ""
  }

  function handleClaudeUsageOutput(text) {
    var raw = String(text || "")
    var marker = "HTTPSTATUS:"
    var idx = raw.lastIndexOf(marker)
    var status = idx >= 0 ? parseInt(raw.slice(idx + marker.length).trim(), 10) : 0
    var body = idx >= 0 ? raw.slice(0, idx) : raw
    if (status >= 200 && status < 300) {
      try {
        finishClaude(parseClaudeUsage(JSON.parse(body), claudePlan))
        return
      } catch (e) {}
    }
    finishClaude({ plan: claudePlan, limits: [] })
  }

  function parseClaudeUsage(payload, plan) {
    payload = payload || ({})
    var buckets = [
      { label: "5h", value: payload.five_hour },
      { label: "7d", value: payload.seven_day || payload.seven_day_oauth_apps }
    ]
    var percentScaled = false
    for (var i = 0; i < buckets.length; i++) {
      var rawBucket = buckets[i].value
      if (!rawBucket || rawBucket.utilization === undefined || rawBucket.utilization === null) continue
      var rawValue = Number(rawBucket.utilization)
      if (!isNaN(rawValue) && rawValue >= 1) percentScaled = true
    }

    var limits = []
    for (var j = 0; j < buckets.length; j++) {
      var bucket = buckets[j].value
      if (!bucket || bucket.utilization === undefined || bucket.utilization === null) continue
      var value = Number(bucket.utilization)
      if (isNaN(value)) continue
      var percent = percentScaled || value > 1 ? value / 100 : value
      limits.push({
        label: buckets[j].label,
        percent: clamp01(percent),
        resetsAt: String(bucket.resets_at || "")
      })
    }
    return { plan: String(plan || ""), limits: limits }
  }

  function finishClaude(result) {
    if (claudeDone) return
    claudeDone = true
    claudeTimeout.stop()
    if (claudeProc.running) claudeProc.running = false
    claudeFresh = result || ({ plan: claudePlan, limits: [] })
    maybeFinalize()
  }

  function startCodex() {
    codexTimeout.interval = 6000
    codexTimeout.restart()
    codexProc.running = true
  }

  function codexWrite(message) {
    if (!codexProc.running) return
    codexProc.write(JSON.stringify(message) + "\n")
  }

  function handleCodexStarted() {
    codexWrite({
      id: 1,
      method: "initialize",
      params: { clientInfo: { name: "dots-shell", version: "1" } }
    })
    codexTimeout.interval = 6000
    codexTimeout.restart()
  }

  function handleCodexLine(line) {
    var message
    try { message = JSON.parse(String(line || "")) } catch (e) { return }
    var id = Number(message && message.id)

    if (id === 1) {
      codexWrite({ method: "initialized", params: {} })
      codexWrite({ id: 2, method: "account/read", params: {} })
      codexTimeout.interval = 4000
      codexTimeout.restart()
      return
    }

    if (id === 2) {
      codexAccount = message && message.result && message.result.account ? message.result.account : ({})
      codexWrite({ id: 3, method: "account/rateLimits/read", params: {} })
      codexTimeout.interval = 4000
      codexTimeout.restart()
      return
    }

    if (id === 3) {
      codexRateLimits = message && message.result && message.result.rateLimits ? message.result.rateLimits : ({})
      finishCodex()
    }
  }

  function codexLimit(window) {
    if (!window || window.usedPercent === undefined || window.usedPercent === null) return null
    var minutes = Math.floor(Number(window.windowDurationMins || 0))
    var label = "limit"
    if (minutes === 10080) label = "7d"
    else if (minutes > 0 && minutes % 60 === 0) label = String(Math.floor(minutes / 60)) + "h"
    return {
      label: label,
      percent: clamp01(Number(window.usedPercent) / 100),
      resetsAt: String(window.resetsAt || "")
    }
  }

  function finishCodex() {
    if (codexDone) return
    codexDone = true
    codexTimeout.stop()

    var limitsPayload = codexRateLimits || ({})
    var account = codexAccount || ({})
    var limits = []
    var primary = codexLimit(limitsPayload.primary)
    var secondary = codexLimit(limitsPayload.secondary)
    if (primary) limits.push(primary)
    if (secondary) limits.push(secondary)
    codexFresh = {
      plan: String(limitsPayload.planType || account.planType || account.type || ""),
      limits: limits
    }

    if (codexProc.running) codexProc.running = false
    maybeFinalize()
  }

  function maybeFinalize() {
    if (!refreshing || !claudeDone || !codexDone) return

    var previous = cachedById()
    var next = []
    var claudePrevious = previous.claude || ({})
    var codexPrevious = previous.codex || ({})

    if (claudeInstalled || (claudeFresh.limits || []).length > 0 || previous.claude)
      next.push(buildRow("claude", "Claude Code", claudeInstalled, claudeFresh, claudePrevious))
    if (codexInstalled || (codexFresh.limits || []).length > 0 || previous.codex)
      next.push(buildRow("codex", "Codex", codexInstalled, codexFresh, codexPrevious))

    rows = next
    saveCache()
    lastUpdatedMs = Date.now()
    refreshing = false
  }

  Process {
    running: true
    command: ["mkdir", "-p", service.cacheRoot]
  }

  FileView {
    id: cacheFile
    path: service.cachePath
    blockLoading: true
    atomicWrites: true
    printErrors: false
  }

  FileView {
    id: credentialsFile
    path: service.claudeRoot + "/.credentials.json"
    blockLoading: true
    printErrors: false
  }

  Process {
    id: probeProc
    command: ["bash", "-lc",
      "command -v claude >/dev/null 2>&1 && echo claude=1 || echo claude=0; " +
      "command -v codex >/dev/null 2>&1 && echo codex=1 || echo codex=0"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: service.parseProbe(text)
    }
  }

  Process {
    id: claudeProc
    command: ["bash", "-lc",
      "read -r token && curl -s --max-time 8 -w '\\nHTTPSTATUS:%{http_code}' " +
      "-H \"Authorization: Bearer $token\" " +
      "-H \"anthropic-beta: oauth-2025-04-20\" " +
      "-H \"Accept: application/json\" " +
      "https://api.anthropic.com/api/oauth/usage"]
    stdinEnabled: true
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: service.handleClaudeUsageOutput(text)
    }
    stderr: StdioCollector {}
    onStarted: service.handleClaudeStarted()
    onExited: if (!service.claudeDone) service.finishClaude({ plan: service.claudePlan, limits: [] })
  }

  Process {
    id: codexProc
    command: [service.home + "/.local/bin/codex", "-s", "read-only", "-a", "on-request", "app-server"]
    stdinEnabled: true
    stdout: SplitParser {
      onRead: data => service.handleCodexLine(data)
    }
    stderr: StdioCollector {}
    onStarted: service.handleCodexStarted()
    onExited: if (!service.codexDone) service.finishCodex()
  }

  Timer {
    id: claudeTimeout
    interval: 10000
    onTriggered: service.finishClaude({ plan: service.claudePlan, limits: [] })
  }

  Timer {
    id: codexTimeout
    interval: 4000
    onTriggered: service.finishCodex()
  }

  Timer {
    id: probeTimeout
    interval: 10000
    onTriggered: {
      if (probeProc.running) probeProc.running = false
      service.parseProbe("")
    }
  }

  Timer {
    interval: 600000
    running: true
    repeat: true
    onTriggered: service.refresh()
  }

  Component.onCompleted: {
    loadCache()
    refresh()
  }
}
