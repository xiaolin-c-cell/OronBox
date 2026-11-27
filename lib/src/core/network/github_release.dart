class GitHubRelease {
  const GitHubRelease({
    required this.name,
    required this.tagName,
    required this.body,
    required this.assets,
  });

  final String name;
  final String tagName;
  final String body;
  final List<GitHubReleaseAsset> assets;

  factory GitHubRelease.fromJson(Map<String, Object?> json) {
    return GitHubRelease(
      name: json['name']?.toString().trim() ?? '',
      tagName: json['tag_name']?.toString().trim() ?? '',
      body: json['body']?.toString() ?? '',
      assets: (json['assets'] as List? ?? const [])
          .whereType<Map>()
          .map((asset) => GitHubReleaseAsset.fromJson(asset.cast()))
          .toList(growable: false),
    );
  }
}

class GitHubReleaseAsset {
  const GitHubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    this.size,
    this.digest,
  });

  final String name;
  final String downloadUrl;
  final int? size;
  final String? digest;

  factory GitHubReleaseAsset.fromJson(Map<String, Object?> json) {
    return GitHubReleaseAsset(
      name: json['name']?.toString().trim() ?? '',
      downloadUrl: json['browser_download_url']?.toString().trim() ?? '',
      size: (json['size'] as num?)?.toInt(),
      digest: json['digest']?.toString(),
    );
  }
}
