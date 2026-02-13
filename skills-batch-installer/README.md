# Docker 批量执行脚本

这个文件夹包含三个 PowerShell 脚本，用于 Docker 容器的批量执行和分布式反爬虫负载测试。

## 脚本概览

### 1. run-docker-batch.ps1 - 基础批量执行

最简单的批量执行脚本，同时运行指定数量的 Docker 容器。

**特性：**
- 指定并发数量（同时运行多少个容器）
- 指定总运行次数
- 每个容器获得唯一的客户端身份信息
- 实时进度显示

**参数：**
```powershell
-Total <int>          # 总运行次数，默认值：20
-Concurrency <int>    # 并发数量，默认值：4
-Image <string>       # Docker 镜像名称，默认值："skills-installer"
```

**使用示例：**
```powershell
# 运行 20 次，4 个并发
.\run-docker-batch.ps1

# 运行 50 次，8 个并发，使用自定义镜像
.\run-docker-batch.ps1 -Total 50 -Concurrency 8 -Image "my-image"

# 快速测试：运行 2 次，1 个并发
.\run-docker-batch.ps1 -Total 2 -Concurrency 1
```

---

### 2. run-docker-batch-scheduled.ps1 - 批次执行（带延迟）

在基础批量执行的基础上增加了批次间延迟功能，模拟真实用户访问模式。

**特性：**
- 基础的并发执行
- 完成一批任务后，等待随机秒数
- 可配置的延迟时间范围
- 可选的随机化延迟
- 完整的统计数据（成功率、执行时间）

**参数：**
```powershell
-Total <int>                 # 总运行次数，默认值：20
-Concurrency <int>           # 并发数量，默认值：4
-MinDelaySeconds <int>       # 最小延迟秒数，默认值：1
-MaxDelaySeconds <int>       # 最大延迟秒数，默认值：30
-Image <string>              # Docker 镜像名称，默认值："skills-installer"
-Randomize <bool>            # 是否随机化延迟，默认值：$true
```

**使用示例：**
```powershell
# 使用默认参数
.\run-docker-batch-scheduled.ps1

# 100 次运行，4 个并发，5-15 秒延迟
.\run-docker-batch-scheduled.ps1 -Total 100 -Concurrency 4 -MinDelaySeconds 5 -MaxDelaySeconds 15

# 不随机化延迟，固定为 10 秒间隔
.\run-docker-batch-scheduled.ps1 -Total 50 -Concurrency 5 -MinDelaySeconds 10 -MaxDelaySeconds 10 -Randomize $false
```

---

### 3. run-docker-waves.ps1 - 波次执行（动态并发）

最高级的脚本，分批处理任务，逐波增加并发数量，模拟渐进式的负载增加。

**特性：**
- 波次执行：分批完成任务
- 动态并发：每个波次增加并发数
- 从低到高的并发扩展
- 波次间的随机延迟
- 详细的性能统计数据

**参数：**
```powershell
-TotalRuns <int>             # 总运行次数，默认值：100
-InitialConcurrency <int>    # 初始并发数，默认值：2
-MaxConcurrency <int>        # 最大并发数，默认值：8
-MinWaveDelaySeconds <int>   # 波次间最小延迟，默认值：5
-MaxWaveDelaySeconds <int>   # 波次间最大延迟，默认值：60
-Image <string>              # Docker 镜像名称，默认值："skills-installer"
```

**使用示例：**
```powershell
# 使用默认参数
.\run-docker-waves.ps1

# 200 次运行，初始 2 并发，最大 10 并发
.\run-docker-waves.ps1 -TotalRuns 200 -InitialConcurrency 2 -MaxConcurrency 10

# 快速测试：30 次运行，初始 1 并发，最大 3 并发，短延迟
.\run-docker-waves.ps1 -TotalRuns 30 -InitialConcurrency 1 -MaxConcurrency 3 -MinWaveDelaySeconds 1 -MaxWaveDelaySeconds 5
```

---

## 使用场景

| 场景 | 推荐脚本 | 原因 |
|------|---------|------|
| 简单的并发测试 | `run-docker-batch.ps1` | 最轻量级，无延迟 |
| 模拟真实用户访问 | `run-docker-batch-scheduled.ps1` | 批次间有停顿，更真实 |
| 压力测试（渐进式负载） | `run-docker-waves.ps1` | 逐波增加压力，观察系统应对 |
| 反爬虫绕过测试 | 任何脚本 | 所有脚本都生成唯一的客户端身份 |

## 运行前的准备

1. **安装 PowerShell**：需要 PowerShell 5.1 或更高版本
2. **安装 Docker**：需要已安装 Docker 并能正常运行
3. **准备镜像**：确保指定的 Docker 镜像已存在
   ```powershell
   docker images  # 查看已有镜像
   ```

## 执行权限

如果脚本无法执行，可能需要调整执行策略：

```powershell
# 仅对当前进程生效
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# 对当前用户生效
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 客户端身份信息

每个容器运行时会接收以下环境变量，用于模拟不同的客户端：

- `DEVICE_ID`：唯一的设备标识符（GUID）
- `CLIENT_UUID`：唯一的客户端标识符（GUID）
- `USER_AGENT`：随机分配的浏览器标识符

这些信息有助于绕过反爬虫检测。

## 输出说明

### 颜色编码
- 🟢 **绿色**：成功、完成状态
- 🔵 **青色**：部分标题、分隔符
- 🟡 **黄色**：进度、配置信息、警告
- 🔴 **红色**：失败、错误
- 🟣 **紫色**：波次标记（仅 wave 脚本）

### 统计数据

脚本完成后会显示：
- 总运行次数
- 成功/失败的运行数
- 成功率百分比
- 总执行时间
- 平均每次执行时间

## 故障排除

| 问题 | 解决方案 |
|------|---------|
| "找不到 Docker 命令" | 确保 Docker 已安装且在 PATH 中 |
| 容器启动失败 | 检查镜像名称是否正确：`docker images` |
| 权限被拒绝 | 使用管理员权限运行 PowerShell |
| 脚本无法执行 | 调整执行策略（见上面的执行权限部分） |

## 快速开始

```powershell
# 进入脚本目录
cd scripts

# 测试运行（2 次，1 并发）
.\run-docker-batch.ps1 -Total 2 -Concurrency 1 -Image "your-image-name"

# 实际运行
.\run-docker-batch-scheduled.ps1 -Total 50 -Concurrency 4 -Image "your-image-name"
```

---

**更多信息**：查看根目录的 `AGENTS.md` 了解代码风格和开发指南。
