import 'package:flutter/cupertino.dart';

/// A category of emoji shown in the icon picker's "Emoji" tab.
class EmojiCategory {
  const EmojiCategory(this.icon, this.name, this.emojis);

  /// SF-symbol used for the category nav button.
  final IconData icon;

  /// Space-separated search terms describing the whole category. Used as a
  /// fallback so every emoji is reachable from search even when it has no
  /// specific keyword entry (e.g. searching "animal" surfaces the whole
  /// Animals category).
  final String name;

  /// The emoji glyphs in this category.
  final List<String> emojis;
}

/// Curated emoji catalogue grouped into categories. Kept intentionally
/// finite (no full Unicode tables / no codegen) so it stays bundled with the
/// app and renders quickly. One glyph per entry — variant selectors / skin
/// tones are omitted to keep the grid clean.
const List<EmojiCategory> kEmojiCatalog = [
  // Smileys & emotion
  EmojiCategory(CupertinoIcons.smiley, 'smileys emotion face faces happy sad emoji feeling mood', [
    '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '🥲', '😊',
    '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙',
    '😚', '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎',
    '🥸', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁',
    '☹️', '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠',
    '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥',
    '😓', '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬',
    '🙄', '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪',
    '😵', '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑',
    '🤠', '😈', '👿', '👹', '👺', '🤡', '💩', '👻', '💀', '☠️',
    '👽', '👾', '🤖', '🎃', '😺', '😸', '😹', '😻', '😼', '😽',
    '🙀', '😿', '😾',
  ]),
  // People & body
  EmojiCategory(CupertinoIcons.hand_raised, 'people person body hand gesture human', [
    '👋', '🤚', '🖐️', '✋', '🖖', '👌', '🤌', '🤏', '✌️', '🤞',
    '🤟', '🤘', '🤙', '👈', '👉', '👆', '👇', '☝️', '👍', '👎',
    '✊', '👊', '🤛', '🤜', '👏', '🙌', '👐', '🤲', '🙏', '✍️',
    '💅', '🤳', '💪', '🦾', '🦵', '🦿', '🦶', '👂', '🦻', '👃',
    '🧠', '🫀', '🫁', '🦷', '🦴', '👀', '👁️', '👅', '👄', '💋',
    '🩸', '👶', '🧒', '👦', '👧', '🧑', '👨', '👩', '🧓', '👴',
    '👵', '🙇', '🤦', '🤷', '👮', '🕵️', '💂', '👷', '🤴', '👸',
    '👰', '🤵', '🧑‍⚕️', '🧑‍🏫', '🧑‍🍳', '🧑‍🌾', '🧑‍🔧', '🧑‍🚀', '🧑‍🚒', '🦸',
    '🦹', '🧙', '🧚', '🧛', '🧜', '🧝', '🧞', '🧟', '🤰', '👼',
    '🎅', '🤶',
  ]),
  // Animals & nature
  EmojiCategory(CupertinoIcons.paw, 'animal animals nature plant flower tree weather pet', [
    '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
    '🦁', '🐮', '🐷', '🐽', '🐸', '🐵', '🙈', '🙉', '🙊', '🐒',
    '🐔', '🐧', '🐦', '🐤', '🐣', '🐥', '🦆', '🦅', '🦉', '🦇',
    '🐺', '🐗', '🐴', '🦄', '🐝', '🪱', '🐛', '🦋', '🐌', '🐞',
    '🐜', '🪰', '🪲', '🦗', '🕷️', '🕸️', '🦂', '🐢', '🐍', '🦎',
    '🦖', '🦕', '🐙', '🦑', '🦐', '🦞', '🦀', '🐡', '🐠', '🐟',
    '🐬', '🐳', '🐋', '🦈', '🐊', '🐅', '🐆', '🦓', '🦍', '🦧',
    '🐘', '🦛', '🦏', '🐪', '🐫', '🦒', '🦘', '🐃', '🐂', '🐄',
    '🐎', '🐖', '🐏', '🐑', '🦙', '🐐', '🦌', '🐕', '🐩', '🦮',
    '🐈', '🐓', '🦃', '🦚', '🦜', '🦢', '🦩', '🕊️', '🐇', '🦝',
    '🦨', '🦡', '🦦', '🦥', '🐁', '🐀', '🐿️', '🦔', '🌵', '🎄',
    '🌲', '🌳', '🌴', '🌱', '🌿', '☘️', '🍀', '🎍', '🪴', '🎋',
    '🍃', '🍂', '🍁', '🍄', '🐚', '🪸', '🌾', '💐', '🌷', '🌹',
    '🥀', '🌺', '🌸', '🌼', '🌻', '🌞', '🌝', '🌛', '🌜', '🌚',
    '🌕', '🌖', '🌗', '🌘', '🌑', '🌒', '🌓', '🌔', '🌙', '🌎',
    '🌍', '🌏', '🪐', '💫', '⭐', '🌟', '✨', '⚡', '☄️', '💥',
    '🔥', '🌪️', '🌈', '☀️', '🌤️', '⛅', '🌥️', '☁️', '🌦️', '🌧️',
    '⛈️', '🌩️', '🌨️', '❄️', '☃️', '⛄', '🌬️', '💧', '💦', '🌊',
  ]),
  // Food & drink
  EmojiCategory(CupertinoIcons.cart, 'food drink fruit vegetable meal eat snack', [
    '🍏', '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🫐',
    '🍈', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑',
    '🥦', '🥬', '🥒', '🌶️', '🫑', '🌽', '🥕', '🫒', '🧄', '🧅',
    '🥔', '🍠', '🥐', '🥯', '🍞', '🥖', '🥨', '🧀', '🥚', '🍳',
    '🧈', '🥞', '🧇', '🥓', '🥩', '🍗', '🍖', '🌭', '🍔', '🍟',
    '🍕', '🥪', '🥙', '🧆', '🌮', '🌯', '🥗', '🥘', '🫕', '🥫',
    '🍝', '🍜', '🍲', '🍛', '🍣', '🍱', '🥟', '🦪', '🍤', '🍙',
    '🍚', '🍘', '🍥', '🥠', '🥮', '🍢', '🍡', '🍧', '🍨', '🍦',
    '🥧', '🧁', '🍰', '🎂', '🍮', '🍭', '🍬', '🍫', '🍿', '🍩',
    '🍪', '🌰', '🥜', '🍯', '🥛', '🍼', '☕', '🍵', '🧃', '🥤',
    '🧋', '🍶', '🍺', '🍻', '🥂', '🍷', '🥃', '🍸', '🍹', '🍾',
    '🧉', '🧊', '🥄', '🍴', '🍽️', '🥣', '🥡', '🥢',
  ]),
  // Activities & sports
  EmojiCategory(CupertinoIcons.sportscourt, 'activity activities sport sports game music art play', [
    '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱',
    '🪀', '🏓', '🏸', '🏒', '🏑', '🥍', '🏏', '🪃', '🥅', '⛳',
    '🪁', '🏹', '🎣', '🤿', '🥊', '🥋', '🎽', '🛹', '🛼', '🛷',
    '⛸️', '🥌', '🎿', '⛷️', '🏂', '🪂', '🏋️', '🤼', '🤸', '⛹️',
    '🤺', '🤾', '🏌️', '🏇', '🧘', '🏄', '🏊', '🤽', '🚣', '🧗',
    '🚵', '🚴', '🏆', '🥇', '🥈', '🥉', '🏅', '🎖️', '🏵️', '🎗️',
    '🎫', '🎟️', '🎪', '🤹', '🎭', '🩰', '🎨', '🎬', '🎤', '🎧',
    '🎼', '🎹', '🥁', '🪘', '🎷', '🎺', '🪗', '🎸', '🪕', '🎻',
    '🎲', '♟️', '🎯', '🎳', '🎮', '🎰', '🧩',
  ]),
  // Travel & places
  EmojiCategory(CupertinoIcons.car, 'travel place places transport vehicle building map city', [
    '🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑', '🚒', '🚐',
    '🛻', '🚚', '🚛', '🚜', '🦯', '🦽', '🦼', '🛴', '🚲', '🛵',
    '🏍️', '🛺', '🚨', '🚔', '🚍', '🚘', '🚖', '🚡', '🚠', '🚟',
    '🚃', '🚋', '🚞', '🚝', '🚄', '🚅', '🚈', '🚂', '🚆', '🚇',
    '🚊', '🚉', '✈️', '🛫', '🛬', '🛩️', '💺', '🛰️', '🚀', '🛸',
    '🚁', '🛶', '⛵', '🚤', '🛥️', '🛳️', '⛴️', '🚢', '⚓', '⛽',
    '🚧', '🚦', '🚥', '🗺️', '🗿', '🗽', '🗼', '🏰', '🏯', '🏟️',
    '🎡', '🎢', '🎠', '⛲', '⛱️', '🏖️', '🏝️', '🏜️', '🌋', '⛰️',
    '🏔️', '🗻', '🏕️', '⛺', '🏠', '🏡', '🏘️', '🏚️', '🏗️', '🏭',
    '🏢', '🏬', '🏣', '🏤', '🏥', '🏦', '🏨', '🏪', '🏫', '🏩',
    '💒', '🏛️', '⛪', '🕌', '🕍', '🛕', '🕋', '⛩️', '🌁', '🌃',
    '🏙️', '🌄', '🌅', '🌆', '🌇', '🌉', '🎇', '🎆', '🌌',
  ]),
  // Objects
  EmojiCategory(CupertinoIcons.lightbulb, 'object objects tool device tech thing item', [
    '⌚', '📱', '💻', '⌨️', '🖥️', '🖨️', '🖱️', '💽', '💾', '💿',
    '📀', '📷', '📸', '📹', '🎥', '📽️', '🎞️', '📞', '☎️', '📟',
    '📠', '📺', '📻', '🎙️', '🎚️', '🎛️', '🧭', '⏱️', '⏲️', '⏰',
    '🕰️', '⌛', '⏳', '📡', '🔋', '🔌', '💡', '🔦', '🕯️', '🪔',
    '🧯', '🛢️', '💸', '💵', '💴', '💶', '💷', '💰', '💳', '💎',
    '⚖️', '🧰', '🔧', '🔨', '⚒️', '🛠️', '⛏️', '🪛', '🔩', '⚙️',
    '🧱', '⛓️', '🧲', '🔫', '💣', '🧨', '🪓', '🔪', '🗡️', '⚔️',
    '🛡️', '🚬', '⚰️', '⚱️', '🏺', '🔮', '📿', '🧿', '💈', '⚗️',
    '🔭', '🔬', '🕳️', '🩹', '🩺', '💊', '💉', '🩸', '🧬', '🦠',
    '🧫', '🧪', '🌡️', '🧹', '🧺', '🧻', '🚽', '🚰', '🚿', '🛁',
    '🛀', '🧼', '🪥', '🪒', '🧽', '🪣', '🧴', '🛎️', '🔑', '🗝️',
    '🚪', '🪑', '🛋️', '🛏️', '🛌', '🧸', '🖼️', '🛍️', '🛒', '🎁',
    '🎈', '🎏', '🎀', '🎊', '🎉', '🎎', '🏮', '🪅', '✉️', '📩',
    '📨', '📧', '📥', '📤', '📦', '🏷️', '📪', '📫', '📬', '📭',
    '📮', '📯', '📜', '📃', '📄', '📑', '🧾', '📊', '📈', '📉',
    '📇', '🗃️', '🗳️', '🗄️', '📋', '📁', '📂', '🗂️', '🗞️', '📰',
    '📓', '📔', '📒', '📕', '📗', '📘', '📙', '📚', '📖', '🔖',
    '🔗', '📎', '🖇️', '📐', '📏', '🧮', '📌', '📍', '✂️', '🖊️',
    '🖋️', '✒️', '🖌️', '🖍️', '📝', '✏️', '🔍', '🔎', '🔏', '🔐',
    '🔒', '🔓',
  ]),
  // Symbols
  EmojiCategory(CupertinoIcons.heart, 'symbol symbols sign shape arrow heart love mark', [
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
    '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '☮️',
    '✝️', '☪️', '🕉️', '☸️', '✡️', '🔯', '🕎', '☯️', '☦️', '🛐',
    '⛎', '♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐',
    '♑', '♒', '♓', '🆔', '⚛️', '🉑', '☢️', '☣️', '📴', '📳',
    '🈶', '🈚', '🈸', '🈺', '🈷️', '✴️', '🆚', '💮', '🉐', '㊙️',
    '㊗️', '🈴', '🈵', '🈹', '🈲', '🅰️', '🅱️', '🆎', '🆑', '🅾️',
    '🆘', '❌', '⭕', '🛑', '⛔', '📛', '🚫', '💯', '💢', '♨️',
    '🚷', '🚯', '🚳', '🚱', '🔞', '📵', '❗', '❕', '❓', '❔',
    '‼️', '⁉️', '🔅', '🔆', '〽️', '⚠️', '🚸', '🔱', '⚜️', '🔰',
    '♻️', '✅', '🈯', '💹', '❇️', '✳️', '❎', '🌐', '💠', 'Ⓜ️',
    '🌀', '💤', '🏧', '🚾', '♿', '🅿️', '🛗', '🈳', '🈂️', '🛂',
    '🛃', '🛄', '🛅', '🚹', '🚺', '🚼', '⚧', '🚻', '🔣', 'ℹ️',
    '🔤', '🔡', '🔠', '🆖', '🆗', '🆙', '🆒', '🆕', '🆓', '0️⃣',
    '1️⃣', '2️⃣', '3️⃣', '4️⃣', '5️⃣', '6️⃣', '7️⃣', '8️⃣', '9️⃣', '🔟',
    '🔢', '#️⃣', '*️⃣', '⏏️', '▶️', '⏸️', '⏯️', '⏹️', '⏺️', '⏭️',
    '⏮️', '⏩', '⏪', '🔼', '🔽', '➡️', '⬅️', '⬆️', '⬇️', '↗️',
    '↘️', '↙️', '↖️', '↕️', '↔️', '↩️', '↪️', '⤴️', '⤵️', '🔀',
    '🔁', '🔂', '🔄', '🔃', '🎵', '🎶', '➕', '➖', '➗', '✖️',
    '♾️', '💲', '💱', '™️', '©️', '®️', '〰️', '➰', '➿', '🔚',
    '🔙', '🔛', '🔝', '🔜', '✔️', '☑️', '🔘', '⚪', '⚫', '🔴',
    '🔵', '🟤', '🟣', '🟢', '🟡', '🟠', '🔺', '🔻', '🔸', '🔹',
    '🔶', '🔷', '🔳', '🔲', '▪️', '▫️', '◾', '◽', '◼️', '◻️',
    '⬛', '⬜', '🟥', '🟧', '🟨', '🟩', '🟦', '🟪', '🟫',
  ]),
  // Flags & time
  EmojiCategory(CupertinoIcons.flag, 'flag flags time clock date calendar', [
    '🏁', '🚩', '🎌', '🏴', '🏳️', '🏳️‍🌈', '🏴‍☠️', '⏰', '⌚', '⏳',
    '📅', '📆', '🗓️', '📇', '🗒️', '🕐', '🕑', '🕒', '🕓', '🕔',
    '🕕', '🕖', '🕗', '🕘', '🕙', '🕚', '🕛',
  ]),
];

/// Specific search keywords for common emojis, keyed by glyph. Emojis not in
/// this map are still searchable via their category's [EmojiCategory.name].
const Map<String, String> kEmojiKeywords = {
  // Smileys & emotion
  '😀': 'grin happy smile', '😃': 'happy smile joy', '😄': 'happy smile laugh',
  '😁': 'grin beaming smile', '😆': 'laugh haha', '😅': 'sweat laugh relief',
  '😂': 'laugh crying tears joy lol', '🤣': 'rofl rolling laugh lmao',
  '🥲': 'smile tear', '😊': 'smile blush happy', '😇': 'angel innocent halo',
  '🙂': 'smile slight', '🙃': 'upside down silly', '😉': 'wink',
  '😌': 'relieved calm', '😍': 'love heart eyes adore', '🥰': 'love hearts adore',
  '😘': 'kiss blow', '😋': 'yum tasty tongue', '😜': 'tongue wink silly',
  '🤪': 'crazy zany goofy', '🤔': 'thinking hmm think', '🤗': 'hug hugging',
  '🤭': 'oops giggle', '🤫': 'shush quiet silence', '😎': 'cool sunglasses',
  '🥳': 'party celebrate birthday', '🤩': 'star struck excited wow',
  '😏': 'smirk', '😒': 'unamused meh', '😔': 'sad pensive down',
  '😞': 'sad disappointed', '😟': 'worried', '🙁': 'frown sad',
  '😣': 'persevere', '😢': 'cry sad tear', '😭': 'cry sob bawling',
  '😤': 'angry steam triumph', '😠': 'angry mad', '😡': 'angry rage mad red',
  '🤬': 'swear curse angry', '🤯': 'mind blown shocked', '😳': 'flushed embarrassed',
  '🥵': 'hot heat sweat', '🥶': 'cold freezing', '😱': 'scream scared fear',
  '😨': 'fear scared', '😰': 'anxious sweat', '😴': 'sleep zzz tired',
  '🤤': 'drool', '😪': 'sleepy tired', '🤢': 'sick nausea', '🤮': 'vomit sick',
  '🤧': 'sneeze sick', '😷': 'mask sick', '🤒': 'sick thermometer fever',
  '🤕': 'hurt injured bandage', '🤑': 'money mouth rich',
  '🤠': 'cowboy hat', '😈': 'devil evil imp', '👿': 'devil angry',
  '👹': 'ogre monster', '👺': 'goblin', '🤡': 'clown', '💩': 'poop poo',
  '👻': 'ghost spooky boo', '💀': 'skull death dead', '☠️': 'skull crossbones poison',
  '👽': 'alien ufo', '👾': 'alien game invader', '🤖': 'robot bot',
  '🎃': 'pumpkin halloween jackolantern',
  // People & body
  '👋': 'wave hello hi bye hand', '👌': 'ok perfect', '✌️': 'peace victory',
  '🤞': 'fingers crossed luck', '🤟': 'love you hand', '🤘': 'rock horns',
  '🤙': 'call me shaka', '👍': 'thumbs up like yes good', '👎': 'thumbs down dislike no bad',
  '✊': 'fist power', '👊': 'fist bump punch', '👏': 'clap applause',
  '🙌': 'raised hands celebrate hooray', '🙏': 'pray thanks please please hands',
  '✍️': 'write writing hand', '💪': 'muscle strong flex arm', '🧠': 'brain mind smart',
  '🫀': 'heart organ', '👀': 'eyes look watch', '👁️': 'eye', '👄': 'mouth lips',
  '💋': 'kiss lips lipstick', '👶': 'baby infant', '🧒': 'child kid',
  '🧑': 'person adult', '👨': 'man male', '👩': 'woman female',
  '👴': 'old man grandpa', '👵': 'old woman grandma', '👮': 'police cop officer',
  '🕵️': 'detective spy', '👷': 'construction worker builder', '🤴': 'prince',
  '👸': 'princess queen', '🤰': 'pregnant', '👼': 'angel baby cherub',
  '🎅': 'santa christmas claus', '🤶': 'mrs claus christmas',
  '🦸': 'superhero hero', '🦹': 'villain', '🧙': 'wizard mage magic',
  '🧚': 'fairy', '🧛': 'vampire dracula', '🧜': 'mermaid', '🧞': 'genie',
  '🧟': 'zombie',
  // Animals & nature
  '🐶': 'dog puppy pet', '🐱': 'cat kitten pet', '🐭': 'mouse', '🐹': 'hamster',
  '🐰': 'rabbit bunny', '🦊': 'fox', '🐻': 'bear', '🐼': 'panda', '🐨': 'koala',
  '🐯': 'tiger', '🦁': 'lion', '🐮': 'cow', '🐷': 'pig', '🐸': 'frog',
  '🐵': 'monkey', '🐔': 'chicken hen', '🐧': 'penguin', '🐦': 'bird',
  '🐤': 'chick baby bird', '🦆': 'duck', '🦅': 'eagle', '🦉': 'owl',
  '🦇': 'bat', '🐺': 'wolf', '🐴': 'horse', '🦄': 'unicorn',
  '🐝': 'bee honeybee', '🐛': 'bug caterpillar', '🦋': 'butterfly',
  '🐌': 'snail', '🐞': 'ladybug', '🐜': 'ant', '🕷️': 'spider',
  '🐢': 'turtle tortoise', '🐍': 'snake', '🦎': 'lizard gecko',
  '🦖': 'dinosaur trex', '🐙': 'octopus', '🦐': 'shrimp', '🦀': 'crab',
  '🐠': 'fish tropical', '🐟': 'fish', '🐬': 'dolphin', '🐳': 'whale',
  '🦈': 'shark', '🐊': 'crocodile alligator', '🐘': 'elephant',
  '🦒': 'giraffe', '🦘': 'kangaroo', '🐄': 'cow', '🐎': 'horse racing',
  '🐑': 'sheep', '🐐': 'goat', '🦌': 'deer', '🐕': 'dog', '🐈': 'cat',
  '🐓': 'rooster', '🦃': 'turkey', '🦚': 'peacock', '🦜': 'parrot',
  '🐇': 'rabbit', '🦔': 'hedgehog', '🌵': 'cactus', '🎄': 'christmas tree',
  '🌲': 'evergreen tree pine', '🌳': 'tree', '🌴': 'palm tree',
  '🌱': 'seedling sprout plant', '🌿': 'herb leaf', '🍀': 'clover luck lucky',
  '🍂': 'autumn leaves fall', '🍁': 'maple leaf autumn', '🍄': 'mushroom',
  '🌾': 'wheat rice grain', '💐': 'bouquet flowers', '🌷': 'tulip flower',
  '🌹': 'rose flower love', '🌺': 'hibiscus flower', '🌸': 'cherry blossom flower sakura',
  '🌼': 'flower daisy blossom', '🌻': 'sunflower flower', '⭐': 'star',
  '🌟': 'star glowing sparkle', '✨': 'sparkles shiny stars', '⚡': 'lightning bolt electric',
  '🔥': 'fire flame hot lit', '🌈': 'rainbow', '☀️': 'sun sunny weather',
  '☁️': 'cloud weather', '❄️': 'snowflake snow cold winter', '☃️': 'snowman winter',
  '💧': 'water drop droplet', '🌊': 'wave ocean sea water', '🌙': 'moon night crescent',
  '🌍': 'earth world globe', '🪐': 'planet saturn space',
  // Food & drink
  '🍎': 'apple fruit red', '🍏': 'apple green fruit', '🍊': 'orange fruit tangerine',
  '🍋': 'lemon fruit', '🍌': 'banana fruit', '🍉': 'watermelon fruit',
  '🍇': 'grapes fruit', '🍓': 'strawberry fruit berry', '🫐': 'blueberries berry',
  '🍒': 'cherries fruit', '🍑': 'peach fruit', '🥭': 'mango fruit',
  '🍍': 'pineapple fruit', '🥥': 'coconut', '🥝': 'kiwi fruit',
  '🍅': 'tomato', '🍆': 'eggplant aubergine', '🥑': 'avocado',
  '🥦': 'broccoli', '🌽': 'corn', '🥕': 'carrot', '🧄': 'garlic',
  '🧅': 'onion', '🥔': 'potato', '🍞': 'bread', '🥐': 'croissant',
  '🥨': 'pretzel', '🧀': 'cheese', '🥚': 'egg', '🍳': 'fried egg cooking',
  '🥓': 'bacon', '🥩': 'steak meat', '🍗': 'chicken leg poultry',
  '🍖': 'meat bone', '🌭': 'hot dog', '🍔': 'burger hamburger',
  '🍟': 'fries chips', '🍕': 'pizza', '🥪': 'sandwich', '🌮': 'taco',
  '🌯': 'burrito wrap', '🥗': 'salad', '🍝': 'pasta spaghetti',
  '🍜': 'ramen noodles soup', '🍲': 'stew soup pot', '🍛': 'curry rice',
  '🍣': 'sushi', '🍱': 'bento lunch', '🍙': 'rice ball onigiri',
  '🍚': 'rice', '🍦': 'ice cream soft serve', '🍨': 'ice cream',
  '🍰': 'cake slice', '🎂': 'birthday cake', '🧁': 'cupcake muffin',
  '🍪': 'cookie biscuit', '🍩': 'donut doughnut', '🍫': 'chocolate',
  '🍬': 'candy sweet', '🍭': 'lollipop candy', '🍯': 'honey',
  '🥛': 'milk glass', '☕': 'coffee tea hot drink', '🍵': 'tea green tea',
  '🥤': 'soda drink cup', '🧋': 'bubble tea boba', '🍺': 'beer',
  '🍻': 'beers cheers', '🥂': 'champagne cheers toast', '🍷': 'wine',
  '🍸': 'cocktail martini', '🍾': 'champagne bottle celebrate',
  // Activities & sports
  '⚽': 'soccer football ball', '🏀': 'basketball ball', '🏈': 'football american',
  '⚾': 'baseball', '🎾': 'tennis', '🏐': 'volleyball', '🏉': 'rugby',
  '🎱': 'pool billiards 8 ball', '🏓': 'ping pong table tennis',
  '🏸': 'badminton', '🥊': 'boxing glove', '🥋': 'martial arts karate',
  '⛳': 'golf', '🎯': 'dart target bullseye aim', '🎳': 'bowling',
  '🎮': 'game controller gaming video game', '🎲': 'dice game',
  '🧩': 'puzzle jigsaw', '🎰': 'slot machine gambling', '♟️': 'chess',
  '🏆': 'trophy win winner award', '🥇': 'gold medal first',
  '🥈': 'silver medal second', '🥉': 'bronze medal third', '🏅': 'medal award',
  '🎨': 'art paint palette', '🎬': 'movie film clapper', '🎤': 'microphone sing karaoke',
  '🎧': 'headphones music', '🎵': 'music note', '🎶': 'music notes song',
  '🎹': 'piano keyboard music', '🥁': 'drum drums', '🎸': 'guitar music',
  '🎺': 'trumpet', '🎻': 'violin', '🎭': 'theater drama masks', '🎪': 'circus tent',
  '🎉': 'party popper celebrate confetti', '🎊': 'confetti party celebrate',
  '🎈': 'balloon party', '🎁': 'gift present birthday',
  // Travel & places
  '🚗': 'car automobile', '🚕': 'taxi cab', '🚙': 'suv car',
  '🚌': 'bus', '🚓': 'police car', '🚑': 'ambulance', '🚒': 'fire truck',
  '🏎️': 'race car racing', '🏍️': 'motorcycle', '🚲': 'bike bicycle',
  '🛴': 'scooter', '🚀': 'rocket space launch', '🛸': 'ufo flying saucer',
  '✈️': 'airplane plane flight travel', '🚁': 'helicopter', '⛵': 'sailboat boat',
  '🚤': 'speedboat boat', '🚢': 'ship cruise', '⚓': 'anchor',
  '🚂': 'train locomotive', '🚆': 'train', '🚇': 'metro subway',
  '🗺️': 'map travel', '🗽': 'statue of liberty new york', '🗼': 'tower eiffel',
  '🏰': 'castle palace', '🎡': 'ferris wheel', '🎢': 'roller coaster',
  '⛲': 'fountain', '🏖️': 'beach', '🏝️': 'island', '🏜️': 'desert',
  '🌋': 'volcano', '⛰️': 'mountain', '🏔️': 'mountain snow',
  '🏕️': 'camping tent', '⛺': 'tent camp', '🏠': 'house home',
  '🏡': 'house home garden', '🏢': 'office building', '🏥': 'hospital',
  '🏦': 'bank', '🏨': 'hotel', '🏫': 'school', '⛪': 'church',
  '🕌': 'mosque', '🌃': 'night city stars', '🏙️': 'city skyline',
  '🌅': 'sunrise', '🌆': 'sunset city dusk', '🌉': 'bridge night',
  '🎆': 'fireworks celebrate', '🎇': 'sparkler fireworks',
  // Objects
  '⌚': 'watch time', '📱': 'phone mobile smartphone iphone', '💻': 'laptop computer',
  '🖥️': 'desktop computer monitor', '⌨️': 'keyboard', '🖱️': 'mouse computer',
  '🖨️': 'printer', '💾': 'floppy disk save', '💿': 'disc cd',
  '📷': 'camera photo', '📸': 'camera flash photo', '📹': 'video camera',
  '🎥': 'movie camera film', '📞': 'phone call telephone', '📺': 'tv television',
  '📻': 'radio', '⏰': 'alarm clock time', '⏱️': 'stopwatch timer',
  '⌛': 'hourglass time', '🔋': 'battery', '🔌': 'plug power electric',
  '💡': 'light bulb idea lamp', '🔦': 'flashlight torch', '🕯️': 'candle',
  '💰': 'money bag cash rich', '💵': 'dollar money cash', '💳': 'credit card payment',
  '💎': 'diamond gem jewel', '⚖️': 'scale balance justice', '🧰': 'toolbox tools',
  '🔧': 'wrench tool fix', '🔨': 'hammer tool', '🛠️': 'tools hammer wrench',
  '⚙️': 'gear settings cog', '🔩': 'bolt nut screw', '🧲': 'magnet',
  '🔪': 'knife cut chef', '🗡️': 'dagger sword', '🛡️': 'shield protect',
  '🔫': 'gun pistol water gun', '💣': 'bomb', '🔮': 'crystal ball fortune magic',
  '🧿': 'evil eye amulet', '🔭': 'telescope', '🔬': 'microscope science',
  '💊': 'pill medicine', '💉': 'syringe shot vaccine', '🩺': 'stethoscope doctor',
  '🧬': 'dna', '🦠': 'germ virus microbe', '🧪': 'test tube science lab',
  '🌡️': 'thermometer temperature', '🧹': 'broom clean sweep', '🧼': 'soap wash',
  '🛁': 'bath tub', '🚿': 'shower', '🔑': 'key', '🗝️': 'key old',
  '🚪': 'door', '🪑': 'chair seat', '🛏️': 'bed sleep', '🧸': 'teddy bear toy',
  '🖼️': 'picture frame painting art', '🛍️': 'shopping bags', '🛒': 'shopping cart trolley',
  '✉️': 'envelope mail email letter', '📧': 'email mail', '📦': 'package box parcel',
  '📫': 'mailbox mail', '📜': 'scroll document', '📄': 'page document file',
  '📊': 'bar chart graph stats', '📈': 'chart up growth graph', '📉': 'chart down decline',
  '📋': 'clipboard', '📁': 'folder file', '📂': 'folder open file', '📰': 'newspaper news',
  '📕': 'book red closed', '📗': 'book green', '📘': 'book blue', '📙': 'book orange',
  '📚': 'books library study', '📖': 'book open read', '🔖': 'bookmark',
  '🔗': 'link chain url', '📎': 'paperclip clip', '📐': 'ruler triangle',
  '📏': 'ruler measure', '🧮': 'abacus math', '📌': 'pin pushpin',
  '📍': 'location pin map marker', '✂️': 'scissors cut', '🖊️': 'pen',
  '📝': 'memo note write pencil', '✏️': 'pencil write', '🔍': 'search magnifying glass find',
  '🔒': 'lock locked secure', '🔓': 'unlock open',
  // Symbols
  '❤️': 'heart love red', '🧡': 'heart orange', '💛': 'heart yellow',
  '💚': 'heart green', '💙': 'heart blue', '💜': 'heart purple',
  '🖤': 'heart black', '🤍': 'heart white', '💔': 'broken heart breakup',
  '💕': 'two hearts love', '💖': 'sparkling heart love', '💗': 'growing heart love',
  '💘': 'heart arrow cupid love', '💝': 'heart gift love', '💯': 'hundred percent perfect score',
  '✅': 'check mark green done complete', '✔️': 'check mark done tick',
  '☑️': 'checkbox checked', '❌': 'cross x wrong cancel no', '⭕': 'circle red o',
  '🛑': 'stop sign', '⚠️': 'warning caution alert', '❗': 'exclamation important',
  '❓': 'question mark', '♻️': 'recycle recycling', '⚛️': 'atom science',
  '☮️': 'peace', '☯️': 'yin yang balance',
  '🔴': 'red circle dot', '🟠': 'orange circle', '🟡': 'yellow circle',
  '🟢': 'green circle', '🔵': 'blue circle', '🟣': 'purple circle',
  '⚫': 'black circle', '⚪': 'white circle', '🟥': 'red square',
  '🟧': 'orange square', '🟨': 'yellow square', '🟩': 'green square',
  '🟦': 'blue square', '🟪': 'purple square', '⬛': 'black square',
  '⬜': 'white square', '🔶': 'orange diamond', '🔷': 'blue diamond',
  '➕': 'plus add', '➖': 'minus subtract', '✖️': 'multiply times x',
  '➗': 'divide division', '♾️': 'infinity', '🔝': 'top up arrow',
  '➡️': 'right arrow', '⬅️': 'left arrow', '⬆️': 'up arrow', '⬇️': 'down arrow',
  // Flags & time
  '🏁': 'checkered flag finish race', '🚩': 'flag red triangle',
  '🏴': 'black flag', '🏳️': 'white flag', '🏳️‍🌈': 'pride rainbow flag lgbt',
  '🏴‍☠️': 'pirate flag jolly roger', '📅': 'calendar date',
  '📆': 'calendar date', '🗓️': 'calendar spiral date',
};

/// Returns a flat list of emojis whose specific keywords or category name
/// match every whitespace-separated token in [query]. Order follows the
/// catalogue; duplicates are removed.
List<String> searchEmojis(String query) {
  final tokens = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return const [];

  final results = <String>[];
  final seen = <String>{};
  for (final category in kEmojiCatalog) {
    for (final emoji in category.emojis) {
      if (seen.contains(emoji)) continue;
      final haystack = '${kEmojiKeywords[emoji] ?? ''} ${category.name}';
      if (tokens.every(haystack.contains)) {
        results.add(emoji);
        seen.add(emoji);
      }
    }
  }
  return results;
}
