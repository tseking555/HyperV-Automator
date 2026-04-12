# HyperV-Automator

一站式 Hyper-V 虚拟机自动化部署工具，通过 PowerShell 脚本一键完成 Hyper-V 环境配置、虚拟交换机创建、系统磁盘制备、批量虚拟机创建与配置，大幅简化本地 Hyper-V 虚拟机集群搭建流程。

## 功能特性

- 一键启用 Windows Hyper-V 功能
- 自动化创建内部虚拟交换机
- 自定义配置虚拟机集群参数（名称、IP、CPU、内存）
- 批量创建、配置虚拟机，统一管理虚拟机生命周期

## 环境要求

- 操作系统：Windows 10/11 专业版/企业版 或 Windows Server 2016 及以上
- 权限：**以管理员身份运行 PowerShell**
- 存储：预留足够磁盘空间（建议≥50GB）
- 网络：可访问互联网（用于下载系统镜像文件）

## 快速部署步骤

### 1. 启用 Hyper-V 功能

执行命令安装 Hyper-V 全部组件，安装完成后**必须重启计算机**生效：
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

### 2. 创建内部虚拟交换机

创建名为 `InternalSwitch` 的内部专用虚拟交换机，用于虚拟机内网通信：
```powershell
New-VMSwitch -Name "InternalSwitch" -SwitchType Internal
```

### 3. 配置虚拟机存储路径

定义虚拟机文件（配置文件、磁盘文件）的统一保存目录，可根据自身需求修改路径：
```powershell
# 示例路径：F:\Hyper-V，建议使用非系统盘
$baseVMpath = "F:\Hyper-V"
```

### 4. 制备虚拟机系统磁盘
执行脚本自动下载系统镜像并生成 `.vhdx` 虚拟磁盘文件（首次执行需等待镜像下载，耗时取决于网络速度）：
```powershell
.\Build-CloudImageBase.ps1
```

### 5. 定义虚拟机集群配置
通过数组声明待创建的虚拟机信息，支持自定义**虚拟机名称、静态IP、CPU核心数、内存大小（单位：GB）**：
```powershell
$vmList = @(
    @{ Name = "king-sys-prod-dns-01"; IP = "192.168.137.1/24"; Cores = "1"; Memory = "1" },
    @{ Name = "king-sys-prod-dns-02"; IP = "192.168.137.2/24"; Cores = "1"; Memory = "1" },
    @{ Name = "king-sys-prod-chrony"; IP = "192.168.137.3/24"; Cores = "1"; Memory = "1" },
    @{ Name = "king-sys-prod-nginx"; IP = "192.168.137.4/24"; Cores = "1"; Memory = "2" },
    @{ Name = "king-sys-prod-postgresql"; IP = "192.168.137.5/24"; Cores = "2"; Memory = "4" },
    @{ Name = "king-sys-prod-mysql"; IP = "192.168.137.6/24"; Cores = "2"; Memory = "4" },
    @{ Name = "king-sys-prod-rke2-01"; IP = "192.168.137.7/24"; Cores = "2"; Memory = "4" },
    @{ Name = "king-sys-prod-rke2-02"; IP = "192.168.137.8/24"; Cores = "2"; Memory = "4" },
    @{ Name = "king-sys-prod-rke2-03"; IP = "192.168.137.9/24"; Cores = "2"; Memory = "4" }
)
```

### 6. 批量创建虚拟机
执行主脚本，自动根据配置创建所有虚拟机并完成基础配置：
```powershell
.\Create-VMs.ps1
```

## 目录结构
```
HyperV-Automator/
├── Build-CloudImageBase.ps1  # 系统磁盘制备脚本
├── Create-VMs.ps1            # 虚拟机批量创建脚本
└── README.md                 # 项目说明文档
```

## 注意事项
1. 所有 PowerShell 命令**必须以管理员身份运行**，否则会因权限不足执行失败
2. Hyper-V 安装后必须重启电脑，否则后续虚拟化功能无法使用
3. 虚拟机存储路径建议使用**英文路径**，避免中文/特殊字符导致报错
4. 虚拟磁盘下载过程中请勿中断脚本，中断后需删除临时文件重新执行
5. 虚拟机IP网段需与虚拟交换机网段保持一致，默认网段：`192.168.137.0/24`

## 常见问题
### 1. 执行脚本提示“无法加载文件，因为在此系统上禁止运行脚本”
解决方法：执行以下命令开启脚本执行权限：
```powershell
Set-ExecutionPolicy RemoteSigned -Force
```