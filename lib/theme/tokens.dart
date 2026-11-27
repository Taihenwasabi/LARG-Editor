/// 设计令牌的统一入口（间距 / 圆角 / 动效 / 断点）。
///
/// 页面只从这里取令牌，不直接依赖 `fifty_tokens`——
/// 日后整体换执行层时只改这一处。
///
/// 注意：FDL 令牌是运行时 getter，**不能**用在 `const` 构造里。
library;

export 'package:fifty_tokens/fifty_tokens.dart'
    show FiftyBreakpoints, FiftyMotion, FiftyRadii, FiftySpacing;
