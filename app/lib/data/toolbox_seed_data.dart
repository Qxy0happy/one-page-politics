import '../models/toolbox_models.dart';

/// 选择题防错速览。内容来自《澄潇宇考研政治主张整理.md》的方法部分。
const List<ChoiceStrategy> choiceStrategies = [
  ChoiceStrategy(
    title: '单选',
    points: [
      '读题画圈：勾出关键词与墓碑词；材料很长时先看最后一句设问。',
      '先错后对、夹逼出答案：先排明显错误项，排完三个即选剩下。',
      '三项连连看：选项之间互相印证，找共同指向。',
      '举例代入：抽象选项用具体特例检验，荒唐即错。',
      '反驳自己：问“你的意思是……呗？”，用常识检验选项。',
    ],
  ),
  ChoiceStrategy(
    title: '多选',
    points: [
      '疑罪从无：没有明显错误就选上。',
      '找错不找对：对的选项太多，只找明显错误项；排不掉就选。',
      '每排必有理：每个排除都要有明确理由。',
      '含正反两面仍选：选项同时讲成绩与问题，往往仍正确。',
    ],
  ),
];

const List<String> whiteListNotes = [
  '“有利于 / 有助于”沾边就选，不要因为不够绝对而排除。',
  '“根本 / 唯一 / 一切 / 直接”并非见字就错；要看题目和搭配。',
  '具体错不代表完整错；该比的时候要比；“直接”不一定错；“一切”有反例。',
];

const List<TombstoneCategory> tombstoneCategories = [
  TombstoneCategory(
    name: '绝对化',
    words: ['一切', '所有', '唯一', '完全', '彻底', '无条件', '一成不变', '亘古不变', '始终'],
    strategy: '先圈出再斟酌，多数为错。',
    boundary: '“一切”有反例；不要机械排除。',
  ),
  TombstoneCategory(
    name: '“一”字类',
    words: ['唯一', '一元', '统一', '完全一样', '一条路', '一种模式', '一脉相承'],
    strategy: '“只走一条道路、一种模式”必错。',
    boundary: '“一脉相承”在文化、历史语境中常为正确表述。',
  ),
  TombstoneCategory(
    name: '过度具体',
    words: ['具体', '细致', '完整', '全面'],
    strategy: '马原和历史题中“具体”多为错；但“具体”错不等于“完整”错。',
    boundary: '看修饰对象；完整、全面并非一律错。',
  ),
  TombstoneCategory(
    name: '简单化／加和',
    words: ['纯粹', '简单加和', '线性', '自发', '自然', '自然而然', '自然显露'],
    strategy: '“纯粹关系”“自然显露价值”多为错。',
    boundary: '“自发”在市场经济语境中可有条件成立。',
  ),
  TombstoneCategory(
    name: '夸张／程度',
    words: ['根本', '决定', '主导', '取代', '创造', '全面清除'],
    strategy: '程度夸大；要看题目，不一律杀。',
    boundary: '“根本”“决定”在教材原话中大量正确。',
  ),
  TombstoneCategory(
    name: '时态',
    words: ['已经', '已实现', '已形成', '已完成'],
    strategy: '2035／2050 目标、现代化经济体系等常考“尚未完成”。',
    boundary: '已经完成的历史事件当然可用“已经”。',
  ),
  TombstoneCategory(
    name: '唯心',
    words: ['由主观意志决定', '认识决定存在', '观念创造联系'],
    strategy: '直接排除。',
    boundary: '注意区分“意识能动作用”与“意识决定物质”。',
  ),
  TombstoneCategory(
    name: '范围错配',
    words: ['所有政党', '任何历史时期', '国内题给国际项', '经济题给文化项'],
    strategy: '注意主体和领域限定。',
    boundary: '先看题干问的是谁、哪个领域。',
  ),
  TombstoneCategory(
    name: '数量／质量',
    words: ['就业率', '失业率'],
    strategy: '问“就业质量”不能选“失业率”。',
    boundary: '数量指标与质量指标不要混用。',
  ),
  TombstoneCategory(
    name: '范畴不统一',
    words: ['答非所问'],
    strategy: '题目问什么就答什么。',
    boundary: '选项本身正确也可能因范畴不符而错。',
  ),
];

const List<BigQuestionAngle> bigQuestionAngles = [
  BigQuestionAngle(label: '党', usage: '党的领导确保方向正确，显示党的领导的优越性。'),
  BigQuestionAngle(label: '理论', usage: '归根结底是马克思主义行，是社会主义初级阶段的必然选择。'),
  BigQuestionAngle(label: '制度', usage: '彰显制度优越性。'),
  BigQuestionAngle(label: '路线', usage: '中国特色社会主义道路在新时代的具体实践和拓展。'),
  BigQuestionAngle(label: '历史', usage: '不是突然出现，是红色血脉的延续，是百年奋斗的历史结论。'),
  BigQuestionAngle(label: '文化', usage: '契合中国特色社会主义文化，扎根中华优秀传统文化。'),
  BigQuestionAngle(label: '现实', usage: '符合国情、阶段、物质条件，顺应时代和世界趋势。'),
  BigQuestionAngle(label: '成就', usage: '经济发展＋社会稳定两大奇迹。'),
  BigQuestionAngle(label: '人民', usage: '满足人民期待，是人民的共同选择，为人民谋福祉。'),
  BigQuestionAngle(label: '环境', usage: '百年未有之大变局，西方单边主义、霸权主义。'),
  BigQuestionAngle(label: '需求', usage: '促进共同富裕、经济发展和社会稳定的需要。'),
  BigQuestionAngle(label: '未来', usage: '开辟新境界、指明方向，提供中国方案，为民族复兴提供动力。'),
  BigQuestionAngle(label: '问题', usage: '发展产生新问题、新考验，必须牢牢把握……'),
];

const ThreeInOneTemplate threeInOneTemplate = ThreeInOneTemplate(
  cause: '是……的必然要求／必然选择',
  meaning: '有助于……',
  measure: '我们要……',
);

const List<FrameworkCard> frameworkCards = [
  FrameworkCard(
    title: '五向展开',
    lines: [
      '区别：A 是 A，B 是 B。',
      '联系：联系普遍存在，A 离不开 B。',
      '不可分割：A 不能离开 B，B 也不能离开 A。',
      '发展：用发展的眼光看 A 与 B。',
      '不能：不能把二者割裂，反对只看一面，反对教条主义、经验主义、绝对主义、相对主义。',
    ],
  ),
  FrameworkCard(
    title: '戴帽子句式',
    lines: [
      'A 是 B 的重要基础／重要保障／重要支撑和重要支柱／得分的关键／应有之意／历史必然性的体现／必然选择／重要法宝／出发点和落脚点……',
      '关键：避开“根本”“首要”等最高级词，就可以较自由地套用。',
    ],
  ),
  FrameworkCard(
    title: '抄材料铁律',
    lines: [
      '四不抄：文学化表达、比喻修辞、普通人的讲话、具体数字或过于具体的例子。',
      '最粗暴法：把多余内容删掉，剩下的全抄。',
      '降重四法：同义替换、句式变换、拓展补充、概括归纳。',
      '定位法：盯住目标句，其上、其下都可抄；抄不动时隔一句抄一下。',
      '排版：开头、结尾必须点题；分段论述，不分点。',
    ],
  ),
];

const List<SubjectPocketCard> subjectPocketCards = [
  SubjectPocketCard(
    subject: '马原',
    sections: [
      '四条原理：辩证法、认识论（含真理）、唯物论、唯物史观。',
      '打靶法：多写几条原理各一句，写多不扣分。',
      '决定关系用车轱辘话：A 决定 B，B 反作用于 A，二者协调发展。',
      '“一个问题是个性，一类问题是共性”，写“共性寓于个性之中”。',
    ],
  ),
  SubjectPocketCard(
    subject: '新思想',
    sections: [
      '十二角度完全适用；必写党的领导。',
      '高质量发展是全面建设社会主义现代化国家的首要任务。',
      '中国式现代化帽子用口诀对应。',
      '谈世界意义只记两点：拉踩西方、帮助发展中国家。',
    ],
  ),
  SubjectPocketCard(
    subject: '思修',
    sections: ['五词：理、担、吃、奋、信（理想、担当、吃苦、奋斗、信念）。', '理想与现实、吃苦与收获。', '写满、写得昂扬即可。'],
  ),
  SubjectPocketCard(
    subject: '史纲',
    sections: [
      '两大矛盾、两大历史任务。',
      '四个时期排比：新民主主义革命时期、社会主义革命和建设时期、改革开放和社会主义现代化建设新时期、党的十八大以来。',
      '抗战题有专门模板，不能纯抄。',
    ],
  ),
  SubjectPocketCard(
    subject: '当代',
    sections: [
      '万能开头三段：世界大变局、西方单边主义、人类进步大方向不变。',
      '主体写中国的大国担当、人类命运共同体、全球治理。',
      '一带一路、文明、科技、数字经济可互换。',
      '讲好中国故事、塑造可信可爱可敬的中国形象。',
    ],
  ),
];

const List<String> bigQuestionReminders = [
  '总原则：不背模板，抄材料＋角度框架；写满；一小时选择、两小时大题。',
  '字写大、填满；首尾点题；分段不分点（水平不高时不要分点）。',
  '水区抄材料可到 35–40 分，旱区 20–25 分；选择题 30 分左右，总分五六十已有容错空间。',
];
