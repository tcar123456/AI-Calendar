import 'package:flutter/material.dart';

/// 可拖動的麥克風懸浮按鈕
/// 可以在螢幕任何位置移動，但會自動吸附到左右邊界
class DraggableMicButton extends StatefulWidget {
  /// 按鈕點擊回調（傳遞按鈕中心位置）
  final Function(Offset buttonCenter) onPressed;
  
  /// 按鈕顏色
  final Color? backgroundColor;
  
  /// 圖示顏色
  final Color? iconColor;

  const DraggableMicButton({
    super.key,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  State<DraggableMicButton> createState() => _DraggableMicButtonState();
}

class _DraggableMicButtonState extends State<DraggableMicButton> with SingleTickerProviderStateMixin {
  /// 按鈕的實際位置（拖動時的自由位置）
  Offset? _position;
  
  /// 按鈕是否在右側（false 表示在左側）- 用於吸附
  bool _isOnRight = true;
  
  /// 按鈕大小
  static const double _buttonSize = 56.0;
  
  /// 邊緣內距
  static const double _edgePadding = 16.0;
  
  /// 是否正在拖動
  bool _isDragging = false;
  
  /// 展開動畫控制器
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    
    // 初始化展開動畫控制器
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 初始化默認位置（右側中間偏下）
    if (_position == null) {
      final screenSize = MediaQuery.of(context).size;
      final statusBarHeight = MediaQuery.of(context).padding.top;
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      
      // 預留底部導航欄的空間（約 70 + 安全區域）
      final bottomNavHeight = 70 + bottomPadding;
      
      // 計算初始垂直位置（螢幕中間偏下）
      final initialY = screenSize.height - bottomNavHeight - _buttonSize - 80;
      
      _position = Offset(
        screenSize.width - _buttonSize - _edgePadding,
        initialY,
      );
      
      // 強制更新以顯示按鈕
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 如果位置尚未初始化，返回空 widget
    if (_position == null) {
      return const SizedBox.shrink();
    }
    
    final screenSize = MediaQuery.of(context).size;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // 計算實際顯示位置（拖動中顯示跟隨位置，否則顯示吸附後的位置）
    Offset displayPosition;
    
    if (_isDragging) {
      // 拖動中：顯示實際跟隨位置
      displayPosition = _position!;
    } else {
      // 未拖動：吸附到邊界
      displayPosition = Offset(
        _isOnRight 
            ? screenSize.width - _buttonSize - _edgePadding
            : _edgePadding,
        _position!.dy,
      );
    }

    return AnimatedPositioned(
      duration: _isDragging 
          ? Duration.zero  // 拖動時無延遲
          : const Duration(milliseconds: 300),  // 吸附時有動畫
      curve: Curves.easeOutCubic,
      top: displayPosition.dy,
      left: displayPosition.dx,
      child: GestureDetector(
        // 處理拖動開始
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
            // 如果正在播放縮小動畫，取消它並恢復原狀
            if (_expandController.isAnimating) {
              _expandController.reset();
            }
          });
        },
        // 處理拖動更新
        onPanUpdate: (details) {
          if (_position == null) return;
          
          setState(() {
            // 更新位置：跟隨手指移動
            double newX = _position!.dx + details.delta.dx;
            double newY = _position!.dy + details.delta.dy;
            
            // 預留底部導航欄的空間（約 70 + 安全區域）
            final bottomNavHeight = 70 + bottomPadding;
            
            // 限制在螢幕範圍內（避免被頂部狀態欄和底部導航欄遮擋）
            newX = newX.clamp(0.0, screenSize.width - _buttonSize);
            newY = newY.clamp(
              statusBarHeight, 
              screenSize.height - bottomNavHeight - _buttonSize,
            );
            
            _position = Offset(newX, newY);
          });
        },
        // 拖動結束時決定靠左還是靠右
        onPanEnd: (details) {
          if (_position == null) return;
          
          setState(() {
            _isDragging = false;
            final screenCenter = screenSize.width / 2;
            final buttonCenter = _position!.dx + (_buttonSize / 2);
            _isOnRight = buttonCenter > screenCenter;
          });
        },
        // 按下時縮小
        onTapDown: (details) {
          // 播放縮小動畫
          _expandController.forward();
        },
        // 放開時回彈並執行回調
        onTapUp: (details) {
          // 計算按鈕中心位置
          final buttonCenter = Offset(
            displayPosition.dx + (_buttonSize / 2),
            displayPosition.dy + (_buttonSize / 2),
          );
          
          // 回彈動畫
          _expandController.reverse().then((_) {
            // 動畫完成後執行回調
            widget.onPressed(buttonCenter);
          });
        },
        // 取消時也要回彈（例如手指滑出按鈕區域）
        onTapCancel: () {
          // 回彈動畫
          _expandController.reverse();
        },
        child: AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            // 計算縮小動畫的縮放值（從 1.0 縮小到 0.85）
            final scale = 1.0 - (_expandAnimation.value * 0.15);
            
            return Transform.scale(
              scale: scale,
              child: Material(
                color: widget.backgroundColor ?? Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(_buttonSize / 2),
                elevation: 6,
                shadowColor: Colors.black.withOpacity(0.3),
                child: Container(
                  width: _buttonSize,
                  height: _buttonSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_buttonSize / 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.mic,
                    color: widget.iconColor ?? Colors.white,
                    size: 28,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

