// TEMPORARY shared debug sink for the note "lost edits after tab switch"
// investigation. Lets the note editor, NoteController, and DatabaseService all
// append to one on-screen trace (prebuilt iOS builds have no console). Remove
// the whole file — and its usages — once the bug is diagnosed.

const bool kNoteEditDebug = true;

final List<String> kNoteEditLog = <String>[];
int _kNoteEditSeq = 0;

void noteDbg(String msg) {
  if (!kNoteEditDebug) return;
  _kNoteEditSeq++;
  kNoteEditLog.add('$_kNoteEditSeq $msg');
  if (kNoteEditLog.length > 120) {
    kNoteEditLog.removeRange(0, kNoteEditLog.length - 120);
  }
}

String noteTail(String s) {
  final t = s.length <= 8 ? s : s.substring(s.length - 8);
  return t.replaceAll('\n', '⏎');
}

String noteId(String id) => id.length <= 4 ? id : id.substring(0, 4);
