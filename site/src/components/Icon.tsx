import {
  Bot,
  ShieldCheck,
  Globe,
  Terminal,
  Plug,
  Lock,
  BookOpen,
  ArrowLeftRight,
  Pill,
  Star,
  Landmark,
  Search,
  ClipboardList,
  Calendar,
  MessageCircle,
  Wrench,
  Brain,
  Users,
  MapPin,
  Lightbulb,
  Heart,
  Smartphone,
  Download,
  FileText,
  Rocket,
  FileHeart,
  Stethoscope,
  type LucideIcon,
} from "lucide-react";

const iconMap: Record<string, LucideIcon> = {
  bot: Bot,
  "shield-check": ShieldCheck,
  globe: Globe,
  terminal: Terminal,
  plug: Plug,
  lock: Lock,
  "book-open": BookOpen,
  "arrow-left-right": ArrowLeftRight,
  pill: Pill,
  star: Star,
  landmark: Landmark,
  search: Search,
  "clipboard-list": ClipboardList,
  calendar: Calendar,
  "message-circle": MessageCircle,
  wrench: Wrench,
  brain: Brain,
  users: Users,
  "map-pin": MapPin,
  lightbulb: Lightbulb,
  heart: Heart,
  smartphone: Smartphone,
  download: Download,
  "file-text": FileText,
  rocket: Rocket,
  "file-heart": FileHeart,
  stethoscope: Stethoscope,
};

interface Props {
  name: string;
  size?: number;
  className?: string;
}

export default function Icon({ name, size = 20, className }: Props) {
  const IconComponent = iconMap[name];
  if (!IconComponent) return null;
  return <IconComponent size={size} className={className} />;
}
