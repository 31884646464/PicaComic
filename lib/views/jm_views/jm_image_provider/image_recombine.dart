import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:crypto/crypto.dart';

/// 转换自 https://github.com/tonquer/JMComic-qt/blob/main/src/tools/tool.py
int getSegmentationNum(String epsId, String scrambleID, String pictureName) {
  int scrambleId = int.parse(scrambleID);
  int epsID = int.parse(epsId);
  int num = 0;

  if (epsID < scrambleId) {
    num = 0;
  } else if (epsID < 268850) {
    num = 10;
  } else if (epsID > 421926) {
    String string = epsID.toString() + pictureName;
    List<int> bytes = utf8.encode(string);
    String hash = md5.convert(bytes).toString();
    int charCode = hash.codeUnitAt(hash.length - 1);
    int remainder = charCode % 8;
    num = remainder * 2 + 2;
  } else {
    String string = epsID.toString() + pictureName;
    List<int> bytes = utf8.encode(string);
    String hash = md5.convert(bytes).toString();
    int charCode = hash.codeUnitAt(hash.length - 1);
    int remainder = charCode % 10;
    num = remainder * 2 + 2;
  }

  return num;
}

/// 转换自 https://github.com/tonquer/JMComic-qt/blob/main/src/tools/tool.py
Future<Uint8List> segmentationPicture(RecombinationData data) async {
  int num = getSegmentationNum(data.epsId, data.scrambleId, data.bookId);

  if (num <= 1) {
    return data.imgData;
  }

  image.Image srcImg = image.decodeImage(data.imgData)!;

  int blockSize = (srcImg.height / num).floor();
  int remainder = srcImg.height % num;

  List<Map<String, int>> blocks = [];

  for (int i = 0; i < num; i++) {
    int start = i * blockSize;
    int end = start + blockSize + ((i != num - 1) ? 0 : remainder);
    blocks.add({'start': start, 'end': end});
  }

  image.Image desImg = image.Image(width: srcImg.width, height: srcImg.height);

  int y = 0;
  for (int i = blocks.length - 1; i >= 0; i--) {
    var block = blocks[i];
    int currBlockHeight = block['end']! - block['start']!;
    image.Image tempImg = image.copyCrop(srcImg,
        x: 0, y: block['start']!, width: srcImg.width, height: block['end']!);
    await Future.delayed(const Duration(milliseconds: 40));
    image.compositeImage(desImg, tempImg, dstY: y);
    y += currBlockHeight;
  }

  return Uint8List.fromList(image.encodeJpg(desImg));
}

Future<void> recombineImageAndWriteFile(RecombinationData data) async {
  var bytes = await segmentationPicture(data);
  var file = File(data.savePath!);
  if (file.existsSync()) {
    file.deleteSync();
  }
  file.writeAsBytesSync(bytes);
}

class RecombinationData {
  Uint8List imgData;
  String epsId;
  String scrambleId;
  String bookId;
  String? savePath;

  RecombinationData(this.imgData, this.epsId, this.scrambleId, this.bookId,
      [this.savePath]);
}

///启动一个新的线程转换图片
///
/// 直接使用异步会导致卡顿
Future<Uint8List> startRecombineImage(
    Uint8List imgData, String epsId, String scrambleId, String bookId) async {
  var res = await compute(segmentationPicture,
      RecombinationData(imgData, epsId, scrambleId, bookId));
  return res;
}

///启动一个新的线程转换图片并且写入文件
Future<void> startRecombineAndWriteImage(Uint8List imgData, String epsId,
    String scrambleId, String bookId, String savePath) async {
  await compute(recombineImageAndWriteFile,
      RecombinationData(imgData, epsId, scrambleId, bookId, savePath));
}
