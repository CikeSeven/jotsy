import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/cloud_backup_models.dart';
import '../../../core/services/cloud_backup_presets.dart';
import '../../../core/services/cloud_backup_s3.dart';
import '../../../core/services/webdav_models.dart';
import '../../../l10n/app_localizations.dart';
import '../widgets/cloud_backup_config_field.dart';

/// 填写式备份位置（WebDAV / S3）的表单状态：持有输入控制器，从配置载入、
/// 校验后导出配置。页面负责 [dispose]。
sealed class CloudBackupFormFields {
  /// 校验并导出规范化后的配置；不合法时抛出 [CloudBackupFailure.config]。
  Map<String, Object?> toConfig();

  void dispose();

  static CloudBackupFormFields? forKind(
    CloudBackupKind kind,
    Map<String, Object?> config,
  ) {
    return switch (kind) {
      CloudBackupKind.webDav => WebDavFormFields(config),
      CloudBackupKind.s3 => S3FormFields(config),
      _ => null,
    };
  }
}

final class WebDavFormFields extends CloudBackupFormFields {
  WebDavFormFields(Map<String, Object?> config) {
    final parsed = WebDavConfig.fromJson(config);
    serverUrl.text = parsed.serverUrl;
    username.text = parsed.username;
    password.text = parsed.password;
    remoteDirectory.text = parsed.remoteDirectory;
  }

  final serverUrl = TextEditingController();
  final username = TextEditingController();
  final password = TextEditingController();
  final remoteDirectory = TextEditingController();

  @override
  Map<String, Object?> toConfig() {
    try {
      final config = WebDavConfig(
        serverUrl: serverUrl.text,
        username: username.text,
        password: password.text,
        remoteDirectory: remoteDirectory.text,
      ).validate();
      return config.copyWith(serverUrl: config.baseUri.toString()).toJson();
    } on WebDavConfigException catch (error) {
      throw CloudBackupException(CloudBackupFailure.config, error.message);
    }
  }

  @override
  void dispose() {
    serverUrl.dispose();
    username.dispose();
    password.dispose();
    remoteDirectory.dispose();
  }
}

final class S3FormFields extends CloudBackupFormFields {
  S3FormFields(Map<String, Object?> config) {
    final parsed = S3BackupConfig.fromJson(config);
    endpoint.text = parsed.endpoint;
    region.text = parsed.region;
    bucket.text = parsed.bucket;
    accessKeyId.text = parsed.accessKeyId;
    secretAccessKey.text = parsed.secretAccessKey;
    prefix.text = parsed.prefix;
    pathStyle.value = parsed.pathStyle;
  }

  final endpoint = TextEditingController();
  final region = TextEditingController();
  final bucket = TextEditingController();
  final accessKeyId = TextEditingController();
  final secretAccessKey = TextEditingController();
  final prefix = TextEditingController();
  final pathStyle = ValueNotifier<bool>(false);

  @override
  Map<String, Object?> toConfig() {
    return S3BackupConfig(
      endpoint: endpoint.text,
      region: region.text,
      bucket: bucket.text,
      accessKeyId: accessKeyId.text,
      secretAccessKey: secretAccessKey.text,
      prefix: prefix.text,
      pathStyle: pathStyle.value,
    ).validate().toJson();
  }

  @override
  void dispose() {
    endpoint.dispose();
    region.dispose();
    bucket.dispose();
    accessKeyId.dispose();
    secretAccessKey.dispose();
    prefix.dispose();
    pathStyle.dispose();
  }
}

/// 按表单类型渲染字段；[preset] 提供地址模板提示与寻址方式锁定。
class CloudBackupConfigForm extends StatelessWidget {
  const CloudBackupConfigForm({super.key, required this.fields, this.preset});

  final CloudBackupFormFields fields;
  final CloudBackupPreset? preset;

  @override
  Widget build(BuildContext context) {
    return switch (fields) {
      final WebDavFormFields webDav => _WebDavForm(
        fields: webDav,
        preset: preset,
      ),
      final S3FormFields s3 => _S3Form(fields: s3, preset: preset),
    };
  }
}

class _WebDavForm extends StatelessWidget {
  const _WebDavForm({required this.fields, this.preset});

  final WebDavFormFields fields;
  final CloudBackupPreset? preset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CloudBackupConfigField(
          controller: fields.serverUrl,
          icon: FontAwesomeIcons.link,
          labelText: l10n.webDavServerUrl,
          hintText: preset?.urlTemplate ?? l10n.webDavServerUrlHint,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: AppSpacing.m),
        CloudBackupConfigField(
          controller: fields.username,
          icon: FontAwesomeIcons.user,
          labelText: l10n.webDavUsername,
        ),
        const SizedBox(height: AppSpacing.m),
        CloudBackupConfigField(
          controller: fields.password,
          icon: FontAwesomeIcons.lock,
          labelText: l10n.webDavPassword,
          secret: true,
        ),
        const SizedBox(height: AppSpacing.m),
        CloudBackupConfigField(
          controller: fields.remoteDirectory,
          icon: FontAwesomeIcons.folder,
          labelText: l10n.webDavRemoteDirectory,
          hintText: l10n.webDavRemoteDirectoryHint,
        ),
      ],
    );
  }
}

class _S3Form extends StatelessWidget {
  const _S3Form({required this.fields, this.preset});

  final S3FormFields fields;
  final CloudBackupPreset? preset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locked = preset?.virtualHostOnly ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        CloudBackupConfigField(
          controller: fields.endpoint,
          icon: FontAwesomeIcons.link,
          labelText: l10n.s3Endpoint,
          hintText: preset?.urlTemplate ?? l10n.s3EndpointHint,
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: AppSpacing.m),
        CloudBackupConfigField(
          controller: fields.region,
          icon: FontAwesomeIcons.globe,
          labelText: l10n.s3Region,
          hintText: l10n.s3RegionHint,
        ),
        const SizedBox(height: AppSpacing.m),
        CloudBackupConfigField(
          controller: fields.bucket,
          icon: FontAwesomeIcons.bucket,
          labelText: l10n.s3Bucket,
        ),
        const SizedBox(height: AppSpacing.m),
        CloudBackupConfigField(
          controller: fields.accessKeyId,
          icon: FontAwesomeIcons.key,
          labelText: l10n.s3AccessKeyId,
        ),
        const SizedBox(height: AppSpacing.m),
        CloudBackupConfigField(
          controller: fields.secretAccessKey,
          icon: FontAwesomeIcons.lock,
          labelText: l10n.s3SecretAccessKey,
          secret: true,
        ),
        const SizedBox(height: AppSpacing.m),
        CloudBackupConfigField(
          controller: fields.prefix,
          icon: FontAwesomeIcons.folder,
          labelText: l10n.s3Prefix,
          hintText: l10n.s3PrefixHint,
        ),
        const SizedBox(height: AppSpacing.xs),
        ValueListenableBuilder<bool>(
          valueListenable: fields.pathStyle,
          builder: (BuildContext context, bool value, Widget? child) {
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.s3PathStyle),
              subtitle: Text(
                locked ? l10n.s3PathStyleLocked : l10n.s3PathStyleSubtitle,
              ),
              // 只支持虚拟主机寻址的服务锁定为关闭。
              value: locked ? false : value,
              onChanged: locked
                  ? null
                  : (bool next) => fields.pathStyle.value = next,
            );
          },
        ),
      ],
    );
  }
}
