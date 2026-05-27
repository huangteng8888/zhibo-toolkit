# zhibo-toolkit

直播平台视频下载工具集

## 工具

### download_course.sh

自动下载直播课程并重命名。

```bash
./download_course.sh <课程页面URL> [cookies文件] [输出目录]
```

**示例：**
```bash
# 基本用法（自动使用同目录下的cookies.txt和videos目录）
./download_course.sh "https://szb135927.livec.shangzhibo.tv/watch/11842299"

# 指定输出目录
./download_course.sh "https://xxx.livec.shangzhibo.tv/watch/12345" "" ./my_videos
```

**依赖：**
- yt-dlp: `pip install yt-dlp`
- curl
- ffprobe (可选)

**输出文件命名规则：**
```
课程名_第01节_日期_标题.mp4
```

## 项目结构

```
zhibo-toolkit/
├── download_course.sh    # 下载脚本
├── cookies.txt          # cookies文件（需要用户自己提供）
├── videos/              # 视频输出目录（自动创建）
└── README.md
```

## 支持平台

- shangzhibo.tv (尚品直播)
- 其他使用 m3u8 HLS 流媒体的平台

## 使用流程

1. 从浏览器导出 cookies 为 Netscape 格式，保存为 `cookies.txt`
2. 运行脚本：
   ```bash
   ./download_course.sh "课程页面URL"
   ```
3. 视频会自动下载到 `videos/` 目录并按规则重命名