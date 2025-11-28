"use client";

import Link from "next/link";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Building2, MapPin, Clock, DollarSign, ArrowRight } from "lucide-react";
import { PoolStatus, PoolStatusLabels } from "@/types/contract";
import { formatNumber, calculatePercentage } from "@/lib/utils";
import { octasToApt } from "@/lib/config";

interface ProjectCardProps {
  project: {
    id: number;
    name: string;
    description: string;
    location: string;
    targetFunding: number;
    currentFunding: number;
    targetHours: number;
    currentHours: number;
    status: PoolStatus;
    category: string;
  };
}

function getStatusBadgeVariant(status: PoolStatus): "default" | "secondary" | "success" | "warning" | "error" {
  const map: Record<PoolStatus, "default" | "secondary" | "success" | "warning" | "error"> = {
    [PoolStatus.Pending]: "warning",
    [PoolStatus.Active]: "secondary",
    [PoolStatus.Funded]: "success",
    [PoolStatus.Completed]: "default",
    [PoolStatus.Defaulted]: "error",
  };
  return map[status];
}

export function ProjectCard({ project }: ProjectCardProps) {
  const fundingProgress = calculatePercentage(project.currentFunding, project.targetFunding);
  const hoursProgress = calculatePercentage(project.currentHours, project.targetHours);

  return (
    <Link href={`/projects/${project.id}`}>
      <Card hoverable className="h-full overflow-hidden">
        {/* Project Image/Placeholder */}
        <div className="h-40 bg-gradient-to-br from-primary/20 to-secondary/20 flex items-center justify-center">
          <Building2 className="h-12 w-12 text-primary/40" />
        </div>
        
        <CardHeader className="pb-3">
          <div className="flex items-start justify-between gap-2">
            <div>
              <Badge variant={getStatusBadgeVariant(project.status)} className="mb-2">
                {PoolStatusLabels[project.status]}
              </Badge>
              <CardTitle className="text-lg line-clamp-1">{project.name}</CardTitle>
            </div>
          </div>
          <CardDescription className="flex items-center gap-1">
            <MapPin className="h-3 w-3" />
            {project.location}
          </CardDescription>
        </CardHeader>
        
        <CardContent className="space-y-4">
          <p className="text-sm text-text-muted truncate-2">
            {project.description}
          </p>

          {/* Funding Progress */}
          <div>
            <div className="flex justify-between text-sm mb-1">
              <span className="flex items-center gap-1">
                <DollarSign className="h-3 w-3" />
                Funding
              </span>
              <span className="text-xs">
                {formatNumber(octasToApt(project.currentFunding), 0)} / {formatNumber(octasToApt(project.targetFunding), 0)} APT
              </span>
            </div>
            <Progress value={fundingProgress} className="h-1.5" />
          </div>

          {/* Hours Progress */}
          <div>
            <div className="flex justify-between text-sm mb-1">
              <span className="flex items-center gap-1">
                <Clock className="h-3 w-3" />
                Hours
              </span>
              <span className="text-xs">
                {project.currentHours} / {project.targetHours}
              </span>
            </div>
            <Progress value={hoursProgress} className="h-1.5" indicatorClassName="bg-secondary" />
          </div>

          <div className="flex items-center justify-between pt-2">
            <Badge variant="outline" className="text-xs">{project.category}</Badge>
            <span className="text-xs text-primary flex items-center gap-1">
              Details
              <ArrowRight className="h-3 w-3" />
            </span>
          </div>
        </CardContent>
      </Card>
    </Link>
  );
}

