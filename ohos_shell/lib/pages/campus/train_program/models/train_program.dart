class TrainProgram {
  final String fajhh;
  final String nj;
  final String xkmlh;
  final String xsh;
  final String zyh;
  final String zyfxh;
  final String famc;
  final String jhmc;
  final String xwdm;
  final String bylxdm;
  final String xzlxdm;
  final String xdlxdm;
  final String fajhlxm;
  final String ksxndm;

  TrainProgram({
    required this.fajhh,
    required this.nj,
    required this.xkmlh,
    required this.xsh,
    required this.zyh,
    required this.zyfxh,
    required this.famc,
    required this.jhmc,
    required this.xwdm,
    required this.bylxdm,
    required this.xzlxdm,
    required this.xdlxdm,
    required this.fajhlxm,
    required this.ksxndm,
  });

  factory TrainProgram.fromJson(Map<String, dynamic> json) {
    return TrainProgram(
      fajhh: json['FAJHH']?.toString() ?? '',
      nj: json['NJ']?.toString() ?? '',
      xkmlh: json['XKMLH']?.toString() ?? '',
      xsh: json['XSH']?.toString() ?? '',
      zyh: json['ZYH']?.toString() ?? '',
      zyfxh: json['ZYFXH']?.toString() ?? '',
      famc: json['FAMC']?.toString() ?? '',
      jhmc: json['JHMC']?.toString() ?? '',
      xwdm: json['XWDM']?.toString() ?? '',
      bylxdm: json['BYLXDM']?.toString() ?? '',
      xzlxdm: json['XZLXDM']?.toString() ?? '',
      xdlxdm: json['XDLXDM']?.toString() ?? '',
      fajhlxm: json['FAJHLXM']?.toString() ?? '',
      ksxndm: json['KSXNDM']?.toString() ?? '',
    );
  }
}

class TrainProgramDetail {
  final String title;
  final TrainProgramBasicInfo jhFajhb;
  final List<TreeNode> treeList;

  TrainProgramDetail({
    required this.title,
    required this.jhFajhb,
    required this.treeList,
  });

  factory TrainProgramDetail.fromJson(Map<String, dynamic> json) {
    return TrainProgramDetail(
      title: json['title']?.toString() ?? '',
      jhFajhb: TrainProgramBasicInfo.fromJson(
        json['jhFajhb'] as Map<String, dynamic>? ?? {},
      ),
      treeList:
          (json['treeList'] as List<dynamic>?)
              ?.map((e) => TreeNode.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TrainProgramBasicInfo {
  final String fajhh;
  final String nj;
  final String xsh;
  final String zyh;
  final String zyfxh;
  final String zym;
  final String zyfxm;
  final String famc;
  final String jhmc;
  final String xwdm;
  final String bylxdm;
  final String xzlxdm;
  final String xdlxdm;
  final String fajhlxm;
  final String ksxndm;
  final String xqlxdm;
  final String ksxqdm;
  final String pymb;
  final String xdyq;
  final double yqzxf;
  final double kczxf;
  final int kczms;
  final double kczxs;
  final String bz;
  final String xsm;
  final String fajhlx;
  final String xqlxm;
  final String xdlxmc;
  final String xzlxmc;
  final String xnmc;
  final String xqm;
  final String njmc;
  final String bylxmc;
  final String xwm;

  TrainProgramBasicInfo({
    required this.fajhh,
    required this.nj,
    required this.xsh,
    required this.zyh,
    required this.zyfxh,
    required this.zym,
    required this.zyfxm,
    required this.famc,
    required this.jhmc,
    required this.xwdm,
    required this.bylxdm,
    required this.xzlxdm,
    required this.xdlxdm,
    required this.fajhlxm,
    required this.ksxndm,
    required this.xqlxdm,
    required this.ksxqdm,
    required this.pymb,
    required this.xdyq,
    required this.yqzxf,
    required this.kczxf,
    required this.kczms,
    required this.kczxs,
    required this.bz,
    required this.xsm,
    required this.fajhlx,
    required this.xqlxm,
    required this.xdlxmc,
    required this.xzlxmc,
    required this.xnmc,
    required this.xqm,
    required this.njmc,
    required this.bylxmc,
    required this.xwm,
  });

  factory TrainProgramBasicInfo.fromJson(Map<String, dynamic> json) {
    return TrainProgramBasicInfo(
      fajhh: json['fajhh']?.toString() ?? '',
      nj: json['nj']?.toString() ?? '',
      xsh: json['xsh']?.toString() ?? '',
      zyh: json['zyh']?.toString() ?? '',
      zyfxh: json['zyfxh']?.toString() ?? '',
      zym: json['zym']?.toString() ?? '',
      zyfxm: json['zyfxm']?.toString() ?? '',
      famc: json['famc']?.toString() ?? '',
      jhmc: json['jhmc']?.toString() ?? '',
      xwdm: json['xwdm']?.toString() ?? '',
      bylxdm: json['bylxdm']?.toString() ?? '',
      xzlxdm: json['xzlxdm']?.toString() ?? '',
      xdlxdm: json['xdlxdm']?.toString() ?? '',
      fajhlxm: json['fajhlxm']?.toString() ?? '',
      ksxndm: json['ksxndm']?.toString() ?? '',
      xqlxdm: json['xqlxdm']?.toString() ?? '',
      ksxqdm: json['ksxqdm']?.toString() ?? '',
      pymb: json['pymb']?.toString() ?? '',
      xdyq: json['xdyq']?.toString() ?? '',
      yqzxf: (json['yqzxf'] as num?)?.toDouble() ?? 0.0,
      kczxf: (json['kczxf'] as num?)?.toDouble() ?? 0.0,
      kczms: (json['kczms'] as num?)?.toInt() ?? 0,
      kczxs: (json['kczxs'] as num?)?.toDouble() ?? 0.0,
      bz: json['bz']?.toString() ?? '',
      xsm: json['xsm']?.toString() ?? '',
      fajhlx: json['fajhlx']?.toString() ?? '',
      xqlxm: json['xqlxm']?.toString() ?? '',
      xdlxmc: json['xdlxmc']?.toString() ?? '',
      xzlxmc: json['xzlxmc']?.toString() ?? '',
      xnmc: json['xnmc']?.toString() ?? '',
      xqm: json['xqm']?.toString() ?? '',
      njmc: json['njmc']?.toString() ?? '',
      bylxmc: json['bylxmc']?.toString() ?? '',
      xwm: json['xwm']?.toString() ?? '',
    );
  }
}

class TreeNode {
  final String id;
  final String pId;
  final String name;
  final bool open;
  final String urlPath;
  final String title;
  final String? type;
  final String? dataId;

  TreeNode({
    required this.id,
    required this.pId,
    required this.name,
    required this.open,
    required this.urlPath,
    required this.title,
    this.type,
    this.dataId,
  });

  factory TreeNode.fromJson(Map<String, dynamic> json) {
    return TreeNode(
      id: json['id']?.toString() ?? '',
      pId: json['pId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      open: json['open'] == true || json['open'] == 'true',
      urlPath: json['urlPath']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString(),
      dataId: json['dataId']?.toString(),
    );
  }
}

class CourseDetail {
  final String flag;
  final CourseInfo kc;
  final CoursePlanInfo? jhkc;

  CourseDetail({required this.flag, required this.kc, this.jhkc});

  factory CourseDetail.fromJson(Map<String, dynamic> json) {
    final jhkcJson = json['jhkc'];
    return CourseDetail(
      flag: json['flag']?.toString() ?? '',
      kc: CourseInfo.fromJson(json['kc'] as Map<String, dynamic>? ?? {}),
      jhkc: jhkcJson == null
          ? null
          : CoursePlanInfo.fromJson(jhkcJson as Map<String, dynamic>),
    );
  }

  bool get isOpenCourse => flag == '1' && jhkc == null;
}

class CourseInfo {
  final String kch;
  final String kcm;
  final String ywkcm;
  final String xsh;
  final String xsm;
  final String? kkxq;
  final String bybz;
  final String xf;
  final String xs;
  final String? ksrq;
  final String? jsrq;
  final String kcztdm;
  final String kcztsm;
  final String? xxkch;
  final String knzxs;
  final String jkzxs;
  final String sjzxs;
  final String syzxs;
  final String? qzsjzxs;
  final String? tlfdzxs;
  final String? sjzyzxs;
  final String? kwzxs;
  final String? kwxf;
  final String kclbmc;
  final String? kcjbmc;
  final String jxfssm;
  final String? jsm;
  final String? jc;
  final String? cks;
  final String? szdw;
  final String? kcsm;
  final String nrjj;
  final String kslxmc;
  final String? xqm;
  final String? xqh;
  final String? bz;
  final String? sflbmc;
  final String? rsxsdm;
  final String? ksflbdm;
  final String? bzrs;
  final String ywnrjj;
  final String? xkmlh;
  final String? sjzs;
  final String jxdg;
  final String? ywjxdg;
  final String? zyxkdx;
  final String? xkmlm;
  final String kclbdm;
  final String? jysh;
  final String? kcjjdz;

  CourseInfo({
    required this.kch,
    required this.kcm,
    required this.ywkcm,
    required this.xsh,
    required this.xsm,
    this.kkxq,
    required this.bybz,
    required this.xf,
    required this.xs,
    this.ksrq,
    this.jsrq,
    required this.kcztdm,
    required this.kcztsm,
    this.xxkch,
    required this.knzxs,
    required this.jkzxs,
    required this.sjzxs,
    required this.syzxs,
    this.qzsjzxs,
    this.tlfdzxs,
    this.sjzyzxs,
    this.kwzxs,
    this.kwxf,
    required this.kclbmc,
    this.kcjbmc,
    required this.jxfssm,
    this.jsm,
    this.jc,
    this.cks,
    this.szdw,
    this.kcsm,
    required this.nrjj,
    required this.kslxmc,
    this.xqm,
    this.xqh,
    this.bz,
    this.sflbmc,
    this.rsxsdm,
    this.ksflbdm,
    this.bzrs,
    required this.ywnrjj,
    this.xkmlh,
    this.sjzs,
    required this.jxdg,
    this.ywjxdg,
    this.zyxkdx,
    this.xkmlm,
    required this.kclbdm,
    this.jysh,
    this.kcjjdz,
  });

  factory CourseInfo.fromJson(Map<String, dynamic> json) {
    return CourseInfo(
      kch: json['kch']?.toString() ?? '',
      kcm: json['kcm']?.toString() ?? '',
      ywkcm: json['ywkcm']?.toString() ?? '',
      xsh: json['xsh']?.toString() ?? '',
      xsm: json['xsm']?.toString() ?? '',
      kkxq: json['kkxq']?.toString(),
      bybz: json['bybz']?.toString() ?? '',
      xf: json['xf']?.toString() ?? '',
      xs: json['xs']?.toString() ?? '',
      ksrq: json['ksrq']?.toString(),
      jsrq: json['jsrq']?.toString(),
      kcztdm: json['kcztdm']?.toString() ?? '',
      kcztsm: json['kcztsm']?.toString() ?? '',
      xxkch: json['xxkch']?.toString(),
      knzxs: json['knzxs']?.toString() ?? '',
      jkzxs: json['jkzxs']?.toString() ?? '',
      sjzxs: json['sjzxs']?.toString() ?? '',
      syzxs: json['syzxs']?.toString() ?? '',
      qzsjzxs: json['qzsjzxs']?.toString(),
      tlfdzxs: json['tlfdzxs']?.toString(),
      sjzyzxs: json['sjzyzxs']?.toString(),
      kwzxs: json['kwzxs']?.toString(),
      kwxf: json['kwxf']?.toString(),
      kclbmc: json['kclbmc']?.toString() ?? '',
      kcjbmc: json['kcjbmc']?.toString(),
      jxfssm: json['jxfssm']?.toString() ?? '',
      jsm: json['jsm']?.toString(),
      jc: json['jc']?.toString(),
      cks: json['cks']?.toString(),
      szdw: json['szdw']?.toString(),
      kcsm: json['kcsm']?.toString(),
      nrjj: json['nrjj']?.toString() ?? '',
      kslxmc: json['kslxmc']?.toString() ?? '',
      xqm: json['xqm']?.toString(),
      xqh: json['xqh']?.toString(),
      bz: json['bz']?.toString(),
      sflbmc: json['sflbmc']?.toString(),
      rsxsdm: json['rsxsdm']?.toString(),
      ksflbdm: json['ksflbdm']?.toString(),
      bzrs: json['bzrs']?.toString(),
      ywnrjj: json['ywnrjj']?.toString() ?? '',
      xkmlh: json['xkmlh']?.toString(),
      sjzs: json['sjzs']?.toString(),
      jxdg: json['jxdg']?.toString() ?? '',
      ywjxdg: json['ywjxdg']?.toString(),
      zyxkdx: json['zyxkdx']?.toString(),
      xkmlm: json['xkmlm']?.toString(),
      kclbdm: json['kclbdm']?.toString() ?? '',
      jysh: json['jysh']?.toString(),
      kcjjdz: json['kcjjdz']?.toString(),
    );
  }
}

class CoursePlanInfo {
  final CoursePlanId id;
  final String jhxn;
  final String xqlxdm;
  final String xqdm;
  final String fakzh;
  final String? jhkzh;
  final String kcsxdm;
  final String? bz;
  final String kcm;
  final String kcsxmc;
  final String dj;
  final String famc;
  final String? btdkch;
  final String? btdkcm;
  final String? tdkch;
  final String? tdkcm;
  final String kcztdm;
  final String xf;
  final String? kslxdm;
  final String? kslxmc;
  final String xnmc;
  final String xqm;
  final String? bz1;
  final String? bz2;
  final String? bz3;
  final String? xqh;
  final String? xaqm;

  CoursePlanInfo({
    required this.id,
    required this.jhxn,
    required this.xqlxdm,
    required this.xqdm,
    required this.fakzh,
    this.jhkzh,
    required this.kcsxdm,
    this.bz,
    required this.kcm,
    required this.kcsxmc,
    required this.dj,
    required this.famc,
    this.btdkch,
    this.btdkcm,
    this.tdkch,
    this.tdkcm,
    required this.kcztdm,
    required this.xf,
    this.kslxdm,
    this.kslxmc,
    required this.xnmc,
    required this.xqm,
    this.bz1,
    this.bz2,
    this.bz3,
    this.xqh,
    this.xaqm,
  });

  factory CoursePlanInfo.fromJson(Map<String, dynamic> json) {
    return CoursePlanInfo(
      id: CoursePlanId.fromJson(json['id'] as Map<String, dynamic>? ?? {}),
      jhxn: json['jhxn']?.toString() ?? '',
      xqlxdm: json['xqlxdm']?.toString() ?? '',
      xqdm: json['xqdm']?.toString() ?? '',
      fakzh: json['fakzh']?.toString() ?? '',
      jhkzh: json['jhkzh']?.toString(),
      kcsxdm: json['kcsxdm']?.toString() ?? '',
      bz: json['bz']?.toString(),
      kcm: json['kcm']?.toString() ?? '',
      kcsxmc: json['kcsxmc']?.toString() ?? '',
      dj: json['dj']?.toString() ?? '',
      famc: json['famc']?.toString() ?? '',
      btdkch: json['btdkch']?.toString(),
      btdkcm: json['btdkcm']?.toString(),
      tdkch: json['tdkch']?.toString(),
      tdkcm: json['tdkcm']?.toString(),
      kcztdm: json['kcztdm']?.toString() ?? '',
      xf: json['xf']?.toString() ?? '',
      kslxdm: json['kslxdm']?.toString(),
      kslxmc: json['kslxmc']?.toString(),
      xnmc: json['xnmc']?.toString() ?? '',
      xqm: json['xqm']?.toString() ?? '',
      bz1: json['bz1']?.toString(),
      bz2: json['bz2']?.toString(),
      bz3: json['bz3']?.toString(),
      xqh: json['xqh']?.toString(),
      xaqm: json['xaqm']?.toString(),
    );
  }
}

class CoursePlanId {
  final String kch;
  final String fajhh;

  CoursePlanId({required this.kch, required this.fajhh});

  factory CoursePlanId.fromJson(Map<String, dynamic> json) {
    return CoursePlanId(
      kch: json['kch']?.toString() ?? '',
      fajhh: json['fajhh']?.toString() ?? '',
    );
  }
}
