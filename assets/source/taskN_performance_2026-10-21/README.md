# 性能与正常伤害流程续验 · 2026-10-21

状态：本轮接入及自动化续验完成。11组功能检查11,868项断言0失败；第三关满局外成长、正常伤害的实时机器人09:42.73通关。觉醒奥丁极限密集负载仍未通过，整体验收尚未通过；真人未测，零成长对照阵亡。最终数据见 [RESULTS.md](RESULTS.md) 与 [summary.json](summary.json)。

- [实际画面图库](gallery.html) / [性能与内存趋势](results/performance_trend.png)
- [接入范围与契约](integration.md)
- [原始压力命令](pressure_commands.json)
- [回归及正常流程命令](commands.json)
- [源码基线哈希](baseline_hashes.json) / before/source.zip
- candidate_v1～v5：试验候选，保留失败与未采用的方案；candidate_final：已接入并验证的两份游戏代码。
- logs/、results/：实际日志、结构化结果与截图。runtime/为隔离运行副本，已排除Git，不是正式项目入口。

所有存档与设置均隔离；没有提交或推送Git。没有新生成美术或采用外部来源、工具、第三方代码。
