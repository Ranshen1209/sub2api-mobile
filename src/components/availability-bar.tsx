import { View } from 'react-native';

import { useColors } from '@/src/lib/colors';
import type { StatusTimePoint } from '@/src/types/status';

interface AvailabilityBarProps {
  timeline: StatusTimePoint[];
  height?: number;
}

function getSegmentColor(status: number, colors: ReturnType<typeof useColors>) {
  switch (status) {
    case 1:
      return colors.primary;
    case 2:
      return colors.warning;
    case 0:
      return colors.danger;
    default:
      return colors.barTrack;
  }
}

export function AvailabilityBar({ timeline, height = 4 }: AvailabilityBarProps) {
  const colors = useColors();

  if (timeline.length === 0) {
    return <View style={{ height, borderRadius: height / 2, backgroundColor: colors.barTrack }} />;
  }

  return (
    <View style={{ flexDirection: 'row', height, borderRadius: height / 2, overflow: 'hidden' }}>
      {timeline.map((point, index) => (
        <View
          key={index}
          style={{
            flex: 1,
            backgroundColor: getSegmentColor(point.status, colors),
          }}
        />
      ))}
    </View>
  );
}
