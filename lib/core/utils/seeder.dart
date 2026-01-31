import '../services/threshold_service.dart';

class Seeder {
  static Future<void> seedAll(ThresholdService thresholds) async {
    await seedMatils(thresholds);
    await seedBcLwch(thresholds);
    await seedHwchFch(thresholds);
    await seedTeekaChains(thresholds);
    await seedKchDcbl(thresholds);
    await seedJhumkis(thresholds);
    
    await thresholds.save();
  }

  static Future<void> seedMatils(ThresholdService thresholds) async {
    const category = 'Matils';
    _seedItem(thresholds, category, 'Round Matil', true, 
      ['2', '2.5', '3', '3.5', '4', '5', '6'],
      ['Broad Delhi', '2 in 1', '2 in 1 (minnu)', 'Bulb Anjali', 'Bulb Glass', '3+1', 'Batani Anjali']
    );
    _seedItem(thresholds, category, 'Gajje Matil', false, [], [], {
      '1 LINE': ['3', '4', '5', '6', '8'],
      '2 LINE': ['6', '7', '8', '10'],
      '3 LINE': ['8', '10', '12'],
      'ARCH': ['6', '8'],
    });
    _seedItem(thresholds, category, 'Full Balls Matil (Plain)', false, [], [], {
      '1 LINE': ['4', '5', '6', '8'],
      '2 LINE': ['8', '10', '12'],
      '3 LINE': ['12', '15'],
      'ARCH': ['6', '8'],
    });
    _seedItem(thresholds, category, 'Full Balls Matil (Stone)', false, [], [], {
      '1 LINE': ['4', '5', '6', '8'],
      '2 LINE': ['8', '10', '12'],
      '3 LINE': ['12', '15'],
    });
    _seedItem(thresholds, category, 'Full Balls Matil (Enamel)', false, [], [], {
      '1 LINE': ['4', '5', '6', '8'],
      '2 LINE': ['8', '10', '12'],
      '3 LINE': ['12', '15'],
    });
  }

  static Future<void> seedBcLwch(ThresholdService thresholds) async {
    const category = 'BC & LWCH';
    _seedItem(thresholds, category, 'Backchains', true,
      ['2', '2.5', '3', '3.5', '4', '4.5', '5', '6', '8', '10'],
      ['Regular', 'Flat kondi']
    );
    final lwSubItems = ['Batani', 'Bulb Anjali', '5+1', 'Bulb Glass', 'Tyre', 'Tyre mix', '1"+1"', 'New Designs'];
    _seedItem(thresholds, category, 'Less Weight Chains 18"', true, ['4', '5', '6', '8', '10', '12'], lwSubItems);
    _seedItem(thresholds, category, 'Less Weight Chains 20"', true, ['10', '12', '14', '15'], lwSubItems);
  }

  static Future<void> seedHwchFch(ThresholdService thresholds) async {
    const category = 'HWCH & FCH';
    final hwSubItemsFull = ['Batani', 'Bulb Anjali', '5+1', '10+1', 'Tyre', 'Miller(5+1)', 'Miller(10+1)', 'Double bath'];
    
    // 1. Heavy Weight Chains 20"
    _seedItem(thresholds, category, 'Heavy Weight Chains 20"', true,
      ['16', '20'],
      hwSubItemsFull
    );

    // 2. Heavy Weight Chains 24"
    _seedItem(thresholds, category, 'Heavy Weight Chains 24"', true,
      ['16', '20', '24', '25', '28', '30', '32', '35', '40', '50'],
      hwSubItemsFull
    );

    // 3. Heavy Weight Chains (for the 40,50,60 table)
    _seedItem(thresholds, category, 'Heavy Weight Chains', true,
      ['40', '50', '60'],
      ['Batani', '5+1', 'Miller(5+1)']
    );

    // 4. Fancy Chains (Shared)
    _seedItem(thresholds, category, 'Fancy Chains', true,
      ['16', '20', '24', '30', '32', '35', '40', '50'],
      ['Badri', 'Badri Miller', 'Tyre Ball', 'Tyre Ball + Bulb', 'Balls Basha', 'Gubba Delhi', 'Gubba heart', 'Bulb Mudi', 'Delhi', 'Delhi miller']
    );
  }

  static Future<void> seedTeekaChains(ThresholdService thresholds) async {
    const category = 'Teeka Chains';
    _seedItem(thresholds, category, 'Teeka Chains 1', true,
      ['12', '14', '16', '18', '20', '22', '24', '28', '30', '32'],
      ['Image 1', 'Image 2', 'Image 3', 'Image 4', 'Jahangir TC']
    );
    _seedItem(thresholds, category, 'Teeka Chains 2', true,
      ['8', '10', '12', '14', '15', '16', '20', '24', '30', '32', '35', '40', '45', '50', '55', '60', '70'],
      ['KAS HAR', 'KAS NECK', 'KASCHAIN', 'HIP CHAIN']
    );
  }

  static Future<void> seedKchDcbl(ThresholdService thresholds) async {
    const category = 'KCH & DCBL';

    // 1. Kerala Chains (Focussed on the Delhi/Delhi Miller table)
    _seedItem(thresholds, category, 'Kerala Chains', true,
      ['4', '5', '6', '8', '10', '12', '14', '16', '20', '24', '28', '30', '32', '36', '40'],
      ['Delhi', 'Delhi miller', 'hollow rope', 'Minnu D', 'Arunachalum']
    );

    // 2. Delhi Chains & Bracelets (Shared)
    _seedItem(thresholds, category, 'Delhi Chains & Bracelets', true,
      ['3', '4', '5', '6', '8', '10', '12', '14', '16', '18', '20', '24'],
      ['Delhi bracelet', 'Delhi miller bracelet']
    );
  }

  static Future<void> seedJhumkis(ThresholdService thresholds) async {
    const category = 'Jhumkis';
    _seedItem(thresholds, category, 'Jhumkis', true,
      ['1', '1.5', '2', '2.5', '3', '3.5', '4', '4.5', '5', '6', '8'],
      ['LOOSE BALL', 'LB 2 step', 'LB 3 step', 'ATTACH BALL', 'AB 2 step', 'AB 3 step', '3 LINE', '3 LINE BELL', 'NAKAS', 'NAKAS WITH BELL', 'GRAPE', 'PANJRA', 'SQUARE', 'SPIRAL', 'SPIRAL 2 step', 'KASAI TOPS']
    );
  }

  static void _seedItem(
    ThresholdService thresholds, 
    String category, 
    String item, 
    bool isShared,
    List<String> sharedWeights,
    List<String> subItems,
    [Map<String, List<String>>? perSubItemData]
  ) {
    thresholds.setThreshold(category: category, item: item, subItem: '__metadata', weight: 'shared_mode', threshold: isShared ? 1 : 0);
    if (isShared) {
      for (final w in sharedWeights) {
        thresholds.setThreshold(category: category, item: item, subItem: 'shared', weight: w, threshold: null);
      }
      for (final sub in subItems) {
        thresholds.setThreshold(category: category, item: item, subItem: sub, weight: sharedWeights.first, threshold: null);
      }
    } else if (perSubItemData != null) {
      perSubItemData.forEach((sub, weights) {
        for (final w in weights) {
          thresholds.setThreshold(category: category, item: item, subItem: sub, weight: w, threshold: null);
        }
      });
    }
  }
}
