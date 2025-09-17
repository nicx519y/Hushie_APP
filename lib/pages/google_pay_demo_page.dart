import 'package:flutter/material.dart';
import 'package:pay/pay.dart';
import '../services/google_pay_service.dart';

class GooglePayDemoPage extends StatefulWidget {
  const GooglePayDemoPage({super.key});

  @override
  State<GooglePayDemoPage> createState() => _GooglePayDemoPageState();
}

class _GooglePayDemoPageState extends State<GooglePayDemoPage> {
  bool _canUserPay = false;
  bool _isLoading = true;
  String _paymentResult = '';
  double _amount = 1.00;
  final TextEditingController _amountController = TextEditingController(text: '1.00');

  @override
  void initState() {
    super.initState();
    _checkGooglePayAvailability();
  }

  Future<void> _checkGooglePayAvailability() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final canPay = await GooglePayService.canUserPay();
      setState(() {
        _canUserPay = canPay;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _canUserPay = false;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('检查Google Pay可用性失败: $e')),
        );
      }
    }
  }

  void _onPaymentResult(Map<String, dynamic> result) {
    setState(() {
      _paymentResult = result.toString();
    });
    
    // 处理支付结果
    GooglePayService.handlePaymentResult(result);
    
    // 显示支付成功消息
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('支付处理中...'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _updateAmount() {
    final newAmount = double.tryParse(_amountController.text);
    if (newAmount != null && newAmount > 0) {
      setState(() {
        _amount = newAmount;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的金额')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Pay 演示'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Pay 状态',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('检查Google Pay可用性...'),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Icon(
                            _canUserPay ? Icons.check_circle : Icons.error,
                            color: _canUserPay ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _canUserPay ? 'Google Pay 可用' : 'Google Pay 不可用',
                            style: TextStyle(
                              color: _canUserPay ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '支付金额设置',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '金额 (USD)',
                              prefixText: '\$',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _updateAmount,
                          child: const Text('更新'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '当前金额: \$${_amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Pay 支付',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    if (_canUserPay)
                      GooglePayService.buildGooglePayButton(
                        onPaymentResult: _onPaymentResult,
                        paymentItems: GooglePayService.createPaymentItems(
                          amount: _amount.toStringAsFixed(2),
                          currency: 'USD',
                        ),
                        type: GooglePayButtonType.buy,
                        margin: EdgeInsets.zero,
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Google Pay 不可用\n请确保设备支持并已设置Google Pay',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_paymentResult.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '支付结果',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _paymentResult,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: _checkGooglePayAvailability,
              child: const Text('重新检查Google Pay可用性'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}