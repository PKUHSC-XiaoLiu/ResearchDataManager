# ResearchData Manager v0.1.0

ResearchData Manager是一个Windows本地小工具，用于管理`D:\ResearchData`中的项目、实验和原始数据。程序基于Windows PowerShell和WinForms，不需要安装R、Python或其他运行环境。

## 启动

1. 将整个`ResearchDataManager_v0.1.0`文件夹解压到本地。
2. 双击`Start-ResearchDataManager.cmd`。
3. 第一次启动时，程序默认使用`D:\ResearchData`；如果目录不存在，会询问是否创建。

建议把整个程序文件夹长期放到：

```text
D:\ResearchData\04_Automation\ResearchDataManager\
```

然后为`Start-ResearchDataManager.cmd`创建桌面快捷方式。

## 功能

### 1. 总览

- 显示项目数、实验数、原始数据完成数和已分析/归档数。
- 查看项目列表和最近实验。
- 快速打开ResearchData根目录。

### 2. 新增项目

输入项目代码、文件夹名称、项目名称、说明及保密等级后，程序会：

- 创建标准项目目录；
- 生成`PROJECT_README.md`；
- 更新`05_SystemRecords\Project_Register.csv`；
- 记录操作日志。

项目代码建议使用稳定的短代码，例如`IDH2`、`SP100`。项目文件夹可以使用`IDH2_BreastCancer`之类的名称。

### 3. 新建实验

输入项目、日期、实验类型、目的、纸质记录位置、样品分组和重复数后，程序会：

- 自动生成ExpID；
- 创建标准实验数据包；
- 生成`00_README.md`和`Experiment.json`；
- 生成样品表、Processing Log和Exception Log；
- 更新`Experiment_Master_Register.csv`。

### 4. 原始数据入库

选择实验、源文件夹或单个文件，并指定`L0_Native`或`L1_Export`后，程序会：

1. 逐文件计算源SHA-256；
2. 将文件复制到新的时间戳目录；
3. 计算目标SHA-256并进行比较；
4. 生成`manifest_sha256.csv`和`Import_Summary.json`；
5. 可选将目标原始文件设置为只读；
6. 可选复制到独立磁盘/NAS并再次校验；
7. 写入本地导入日志和全局操作日志；
8. 经用户确认后可标记为`RAW_COMPLETE`。

程序只复制源数据，不会删除、移动或覆盖源文件。若校验失败，会保留失败记录并停止。

### 5. 检查与状态

- 检查README、原始数据、SHA-256清单、处理数据、分析文件、结果和独立备份。
- 手动更新实验生命周期状态：`PLANNED`、`IN_PROGRESS`、`RAW_COMPLETE`、`PROCESSING`、`ANALYZED`或`ARCHIVED`。

### 6. 设置

- 修改ResearchData根目录；
- 配置独立备份目录；
- 设置操作者；
- 创建或修复缺失的基础目录；
- 打开日志目录。

个人设置保存在：

```text
%APPDATA%\ResearchDataManager\config.json
```

## 安全规则

- 原始数据入库始终采用复制，不采用移动。
- 每次导入进入一个新的时间戳目录，不覆盖既有导入。
- 校验不一致时停止，失败目录不会被自动删除。
- 备份目录不能位于ResearchData内部，也不能与工作目录位于同一磁盘。
- 项目、实验和状态变化均写入日志。
- `RAW_COMPLETE`仍需要你确认该次导入是否已包含所需全部原始数据。

## 第一版的边界

- 大体量测序数据的复制和哈希可能耗时较长，界面会同步显示当前文件和进度。
- 本版本负责归档和管理，不会自动解释qPCR、CCK8、流式、图像或测序数据。
- 后续可接入已有的qPCR/CCK8分析程序、定时备份、文件搜索、项目归档和Source Data生成模块。

版本：0.1.0  
日期：2026-08-20
