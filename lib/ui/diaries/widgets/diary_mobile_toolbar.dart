import 'dart:async';
import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

List<MobileToolbarItem> buildDiaryMobileToolbarItems() {
  return <MobileToolbarItem>[
    _deleteImageMobileToolbarItem,
    _continueTypingBelowImageToolbarItem,
    _undoMobileToolbarItem,
    _redoMobileToolbarItem,
    blocksMobileToolbarItem,
    _unorderedListMobileToolbarItem,
    _orderedListMobileToolbarItem,
    textDecorationMobileToolbarItem,
    linkMobileToolbarItem,
    _imageMobileToolbarItem,
    quoteMobileToolbarItem,
    dividerMobileToolbarItem,
  ];
}

final MobileToolbarItem _deleteImageMobileToolbarItem = MobileToolbarItem.action(
  itemIconBuilder: (context, editorState, __) {
    final isImage = _isCurrentSelectionImage(editorState);
    return Icon(
      Icons.delete_outline_rounded,
      color:
          isImage
              ? MobileToolbarTheme.of(context).iconColor
              : MobileToolbarTheme.of(context).iconColor.withValues(alpha: 0.35),
    );
  },
  actionHandler: (_, editorState) {
    if (_isCurrentSelectionImage(editorState)) {
      deleteSelectedImageNode(editorState);
    }
  },
);

final MobileToolbarItem _continueTypingBelowImageToolbarItem =
    MobileToolbarItem.action(
      itemIconBuilder: (context, editorState, __) {
        final isImage = _isCurrentSelectionImage(editorState);
        return Icon(
          Icons.keyboard_rounded,
          color:
              isImage
                  ? MobileToolbarTheme.of(context).iconColor
                  : MobileToolbarTheme.of(context).iconColor.withValues(
                    alpha: 0.35,
                  ),
        );
      },
      actionHandler: (_, editorState) {
        if (_isCurrentSelectionImage(editorState)) {
          moveCursorBelowImageAndOpenKeyboard(editorState);
        }
      },
    );

final MobileToolbarItem _undoMobileToolbarItem = MobileToolbarItem.action(
  itemIconBuilder: (context, editorState, __) {
    final enabled = !editorState.undoManager.undoStack.isEmpty;
    return Icon(
      Icons.undo_rounded,
      color:
          enabled
              ? MobileToolbarTheme.of(context).iconColor
              : MobileToolbarTheme.of(context).iconColor.withValues(alpha: 0.35),
    );
  },
  actionHandler: (_, editorState) {
    if (!editorState.undoManager.undoStack.isEmpty) {
      undoCommand.execute(editorState);
    }
  },
);

final MobileToolbarItem _redoMobileToolbarItem = MobileToolbarItem.action(
  itemIconBuilder: (context, editorState, __) {
    final enabled = !editorState.undoManager.redoStack.isEmpty;
    return Icon(
      Icons.redo_rounded,
      color:
          enabled
              ? MobileToolbarTheme.of(context).iconColor
              : MobileToolbarTheme.of(context).iconColor.withValues(alpha: 0.35),
    );
  },
  actionHandler: (_, editorState) {
    if (!editorState.undoManager.redoStack.isEmpty) {
      redoCommand.execute(editorState);
    }
  },
);

final MobileToolbarItem _unorderedListMobileToolbarItem =
    MobileToolbarItem.action(
      itemIconBuilder: (context, editorState, __) {
        final selected = _isCurrentNodeType(
          editorState,
          BulletedListBlockKeys.type,
        );
        final color =
            selected
                ? MobileToolbarTheme.of(context).itemHighlightColor
                : MobileToolbarTheme.of(context).iconColor;
        return AFMobileIcon(
          afMobileIcons: AFMobileIcons.bulletedList,
          color: color,
        );
      },
      actionHandler: (_, editorState) {
        _toggleListType(editorState, BulletedListBlockKeys.type);
      },
    );

final MobileToolbarItem _orderedListMobileToolbarItem = MobileToolbarItem.action(
  itemIconBuilder: (context, editorState, __) {
    final selected = _isCurrentNodeType(editorState, NumberedListBlockKeys.type);
    final color =
        selected
            ? MobileToolbarTheme.of(context).itemHighlightColor
            : MobileToolbarTheme.of(context).iconColor;
    return AFMobileIcon(
      afMobileIcons: AFMobileIcons.numberedList,
      color: color,
    );
  },
  actionHandler: (_, editorState) {
    _toggleListType(editorState, NumberedListBlockKeys.type);
  },
);

final MobileToolbarItem _imageMobileToolbarItem = MobileToolbarItem.action(
  itemIconBuilder: (context, editorState, __) {
    return FaIcon(
      FontAwesomeIcons.image,
      size: 16,
      color: MobileToolbarTheme.of(context).iconColor,
    );
  },
  actionHandler: (context, editorState) {
    unawaited(_pickAndInsertImage(context, editorState));
  },
);

Future<void> _pickAndInsertImage(
  BuildContext context,
  EditorState editorState,
) async {
  final insertionSelection = _captureInsertionSelection(editorState);
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    type: FileType.image,
  );
  if (result == null || result.files.isEmpty) {
    return;
  }
  final path = result.files.first.path;
  if (path == null || path.isEmpty) {
    return;
  }

  final persistedPath = await _persistDiaryImage(path);
  await editorState.insertDiaryImageNode(
    persistedPath,
    insertionSelection: insertionSelection,
  );

  if (!context.mounted) {
    return;
  }
}

Future<String> _persistDiaryImage(String sourcePath) async {
  final sourceFile = File(sourcePath);
  if (!await sourceFile.exists()) {
    return sourcePath;
  }

  final appDir = await getApplicationDocumentsDirectory();
  final imageDir = Directory(p.join(appDir.path, 'diary_images'));
  if (!await imageDir.exists()) {
    await imageDir.create(recursive: true);
  }

  final extension = p.extension(sourcePath);
  final targetName =
      'img_${DateTime.now().microsecondsSinceEpoch}${extension.isEmpty ? '.jpg' : extension}';
  final targetPath = p.join(imageDir.path, targetName);

  await sourceFile.copy(targetPath);
  return targetPath;
}

Selection? _captureInsertionSelection(EditorState editorState) {
  final currentSelection = editorState.selection;
  if (currentSelection != null) {
    return Selection.collapsed(
      Position(
        path: List<int>.from(currentSelection.end.path),
        offset: currentSelection.end.offset,
      ),
    );
  }

  final children = editorState.document.root.children;
  if (children.isEmpty) {
    return null;
  }

  return Selection.collapsed(
    Position(
      path: List<int>.from(children.last.path),
      offset: 0,
    ),
  );
}

bool _isCurrentNodeType(EditorState editorState, String type) {
  final selection = editorState.selection;
  if (selection == null) {
    return false;
  }
  final node = editorState.getNodeAtPath(selection.start.path);
  return node?.type == type;
}

bool _isCurrentSelectionImage(EditorState editorState) {
  return _isCurrentNodeType(editorState, 'image');
}

void _toggleListType(EditorState editorState, String listType) {
  final selection = editorState.selection;
  if (selection == null) {
    return;
  }
  final firstNode = editorState.getNodeAtPath(selection.start.path);
  final isSelected = firstNode?.type == listType;
  editorState.formatNode(
    selection,
    (node) => node.copyWith(
      type: isSelected ? ParagraphBlockKeys.type : listType,
      attributes: <String, Object?>{
        ParagraphBlockKeys.delta: (node.delta ?? Delta()).toJson(),
      },
    ),
    selectionExtraInfo: const <String, Object?>{
      selectionExtraInfoDoNotAttachTextService: true,
    },
  );
}

void deleteSelectedImageNode(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null || !selection.isCollapsed) {
    return;
  }

  final node = editorState.getNodeAtPath(selection.start.path);
  if (node == null || node.type != 'image') {
    return;
  }

  final transaction = editorState.transaction;
  final nextNode = editorState.getNodeAtPath(node.path.next);
  final previousNode = editorState.getNodeAtPath(node.path.previous);

  transaction.deleteNode(node);

  if (nextNode != null) {
    transaction.afterSelection = Selection.collapsed(
      Position(path: nextNode.path, offset: 0),
    );
  } else if (previousNode != null) {
    transaction.afterSelection = Selection.collapsed(
      Position(path: previousNode.path, offset: 0),
    );
  } else {
    transaction.insertNode([0], paragraphNode());
    transaction.afterSelection = Selection.collapsed(
      Position(path: const [0], offset: 0),
    );
  }

  editorState.apply(transaction);
}

void moveCursorBelowImageAndOpenKeyboard(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null || !selection.isCollapsed) {
    return;
  }

  final node = editorState.getNodeAtPath(selection.start.path);
  if (node == null || node.type != 'image') {
    return;
  }

  final targetPath = node.path.next;
  final nextNode = editorState.getNodeAtPath(targetPath);

  if (nextNode == null || nextNode.type != ParagraphBlockKeys.type) {
    final transaction = editorState.transaction;
    transaction.insertNode(targetPath, paragraphNode());
    transaction.afterSelection = Selection.collapsed(
      Position(path: targetPath, offset: 0),
    );
    editorState.apply(transaction);
  } else {
    editorState.selection = Selection.collapsed(
      Position(path: targetPath, offset: 0),
    );
  }

  final updatedSelection = editorState.selection;
  if (updatedSelection != null) {
    editorState.service.keyboardService?.enableKeyBoard(updatedSelection);
  } else {
    editorState.service.keyboardService?.enable();
  }
}

extension DiaryInsertImage on EditorState {
  Future<void> insertDiaryImageNode(
    String src, {
    Selection? insertionSelection,
  }) async {
    final selection = insertionSelection ?? this.selection;
    if (selection == null || !selection.isCollapsed) {
      return;
    }
    final node = getNodeAtPath(selection.end.path);
    if (node == null) {
      return;
    }
    final transaction = this.transaction;
    final imageNode = Node(
      type: 'image',
      attributes: <String, Object?>{
        'url': src,
        'align': 'center',
        'height': null,
        'width': null,
      },
    );

    late final Path nextSelectionPath;

    if (node.type == ParagraphBlockKeys.type && (node.delta?.isEmpty ?? false)) {
      transaction
        ..insertNode(node.path, imageNode)
        ..deleteNode(node);
      nextSelectionPath = node.path;
    } else {
      transaction.insertNode(node.path.next, imageNode);
      nextSelectionPath = node.path.next;
    }

    transaction.afterSelection = Selection.collapsed(
      Position(path: nextSelectionPath, offset: 0),
    );

    await apply(transaction);
  }
}
