const config = require('../issue-checker.json');

function field(body, heading) {
  const escaped = heading.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const match = body.match(new RegExp(`^#{2,4} ${escaped}\\r?\\n([\\s\\S]*?)(?=^#{2,4} |$(?![\\s\\S]))`, 'm'));
  return match ? match[1].trim() : null;
}

function classifyIssue(issue) {
  const title = issue.title || '';
  const body = issue.body || '';
  // 排除“但 Windows 桌面版正常”等明确不受影响的平台描述。
  const platformTitle = title.replace(/(?:但|而|但是)[^，。；;\n]*(?:正常|没问题|无异常)/g, '');
  const platform = field(body, '运行平台 / Operating System') ?? field(body, '复现平台');
  const module = field(body, '涉及功能模块 / Subsystem or Feature');
  // 老模板可能只留下 [Bug] / [Feature] 标题：只参考首段描述，避免扫描日志或整篇 RFC。
  const genericTitle = /^[\s\[\]【】]*(?:bug|feature|feature request)[\s\[\]【】]*$/i.test(title);
  const summary = genericTitle ? (field(body, 'Bug 描述') ?? field(body, '功能描述 / Feature Description') ?? '')
    .split(/\r?\n\s*\r?\n/).find(line => line.trim() && !line.trim().startsWith('#')) || '' : '';
  const moduleText = `${title}\n${summary.slice(0, 500)}`;
  const desired = new Set();
  const matchPattern = (text, rule) => rule.pattern && new RegExp(rule.pattern, 'i').test(text);
  for (const rule of config.platforms) {
    const matches = platform !== null ? rule.values.includes(platform)
      || platform.split(/[,，/]/).some(value => rule.values.includes(value.trim()))
      : matchPattern(platformTitle, rule);
    if (matches) desired.add(rule.name);
  }
  for (const rule of config.modules) {
    if (module !== null ? rule.values.includes(module) : matchPattern(moduleText, rule)) {
      desired.add(rule.name);
    }
  }
  for (const rule of config.extra) {
    if (matchPattern(moduleText, rule)) desired.add(rule.name);
  }
  for (const rule of config.types) {
    if (matchPattern(title, rule)) desired.add(rule.name);
  }
  return desired;
}

async function ensureLabel(github, repo, name, existing) {
  if (existing.has(name)) return;
  try {
    await github.rest.issues.createLabel({
      ...repo, name, color: name.startsWith('platform:') ? '1d76db' : '5319e7',
      description: `Issue 自动分类：${name}`,
    });
  } catch (error) {
    if (error.status !== 422) throw error;
    // 跨 Issue 的并发首次创建只在标签确实存在时放行。
    await github.rest.issues.getLabel({ ...repo, name });
  }
  existing.add(name);
}

async function removeLabel(github, repo, issue_number, name) {
  try {
    await github.rest.issues.removeLabel({ ...repo, issue_number, name });
  } catch (error) {
    if (error.status !== 404) throw error;
  }
}

async function triageIssue({ github, context, core }) {
  const repo = context.repo;
  const issue_number = context.payload.issue.number;
  // 使用最新正文，避免排队的旧 edited 事件恢复过时标签。
  const { data: issue } = await github.rest.issues.get({ ...repo, issue_number });
  const current = new Set(issue.labels.map(label => label.name));
  const desired = classifyIssue(issue);
  const existing = new Set((await github.paginate(github.rest.issues.listLabelsForRepo, {
    ...repo, per_page: 100,
  })).map(label => label.name));
  for (const name of desired) await ensureLabel(github, repo, name, existing);
  const additions = [...desired].filter(name => !current.has(name));
  if (additions.length) await github.rest.issues.addLabels({ ...repo, issue_number, labels: additions });
  // 只清理成功识别的分类组；未识别的平台或模块保留现有人工分类。
  // discussion / audience 与类型标签只增不删，避免关键字缺失覆盖人工判定。
  const managed = [config.platforms, config.modules]
    .filter(rules => rules.some(rule => desired.has(rule.name)))
    .flatMap(rules => rules.map(rule => rule.name));
  for (const name of managed) {
    if (current.has(name) && !desired.has(name)) await removeLabel(github, repo, issue_number, name);
  }
  core.info(`Issue #${issue_number} 分类：${[...desired].join(', ') || '未识别，保留人工分类'}`);
}

async function setTeamLabel({ github, context, isMember }) {
  const repo = context.repo;
  const issue_number = context.payload.issue.number;
  const name = config.team.name;
  const { data: issue } = await github.rest.issues.get({ ...repo, issue_number });
  const current = new Set(issue.labels.map(label => label.name));
  if (isMember && !current.has(name)) {
    await ensureLabel(github, repo, name, new Set());
    await github.rest.issues.addLabels({ ...repo, issue_number, labels: [name] });
  } else if (!isMember && current.has(name)) {
    await removeLabel(github, repo, issue_number, name);
  }
}

module.exports = { classifyIssue, triageIssue, setTeamLabel };
