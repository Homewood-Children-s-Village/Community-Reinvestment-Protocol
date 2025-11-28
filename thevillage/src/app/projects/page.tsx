"use client";

import { useState } from "react";
import Link from "next/link";
import { MainLayout } from "@/components/Navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { Progress } from "@/components/ui/progress";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Building2,
  Search,
  Filter,
  MapPin,
  Clock,
  Users,
  DollarSign,
  ArrowRight,
} from "lucide-react";
import { PoolStatus, PoolStatusLabels } from "@/types/contract";
import { formatNumber, calculatePercentage, aptToUsd, formatUsd } from "@/lib/utils";
import { octasToApt } from "@/lib/config";

// Mock projects for demonstration
const MOCK_PROJECTS = [
  {
    id: 1,
    name: "Homewood Family Home Restoration",
    description: "Complete restoration of a distressed family home including roof repair, plumbing, and electrical updates.",
    location: "Homewood, PA",
    targetFunding: 50000 * 100000000, // 50,000 APT in octas
    currentFunding: 35000 * 100000000,
    targetHours: 500,
    currentHours: 320,
    status: PoolStatus.Active,
    category: "Home Repair",
    createdAt: Date.now() - 86400000 * 30,
    imageUrl: "/house.png",
  },
  {
    id: 2,
    name: "Community Youth Center Renovation",
    description: "Renovate and expand the local youth center to provide more space for after-school programs.",
    location: "Homewood, PA",
    targetFunding: 75000 * 100000000,
    currentFunding: 45000 * 100000000,
    targetHours: 1000,
    currentHours: 650,
    status: PoolStatus.Active,
    category: "Community Space",
    createdAt: Date.now() - 86400000 * 45,
    imageUrl: null,
  },
  {
    id: 3,
    name: "Senior Housing Accessibility Upgrades",
    description: "Install ramps, grab bars, and other accessibility features in senior housing units.",
    location: "Homewood, PA",
    targetFunding: 25000 * 100000000,
    currentFunding: 25000 * 100000000,
    targetHours: 200,
    currentHours: 200,
    status: PoolStatus.Funded,
    category: "Accessibility",
    createdAt: Date.now() - 86400000 * 60,
    imageUrl: null,
  },
  {
    id: 4,
    name: "Urban Garden Initiative",
    description: "Transform vacant lots into productive community gardens providing fresh produce to residents.",
    location: "Homewood, PA",
    targetFunding: 15000 * 100000000,
    currentFunding: 8000 * 100000000,
    targetHours: 300,
    currentHours: 150,
    status: PoolStatus.Active,
    category: "Green Space",
    createdAt: Date.now() - 86400000 * 15,
    imageUrl: null,
  },
];

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

export default function ProjectsPage() {
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("all");
  const [categoryFilter, setCategoryFilter] = useState<string>("all");

  const categories = [...new Set(MOCK_PROJECTS.map((p) => p.category))];

  const filteredProjects = MOCK_PROJECTS.filter((project) => {
    const matchesSearch =
      project.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      project.description.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesStatus =
      statusFilter === "all" || project.status.toString() === statusFilter;
    const matchesCategory =
      categoryFilter === "all" || project.category === categoryFilter;
    return matchesSearch && matchesStatus && matchesCategory;
  });

  return (
    <MainLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
          <div>
            <h1 className="text-2xl font-bold mb-2">Community Projects</h1>
            <p className="text-text-muted">
              Discover and contribute to neighborhood improvement projects
            </p>
          </div>
          <div className="flex items-center gap-2">
            <Badge variant="secondary" className="text-lg px-3 py-1">
              {MOCK_PROJECTS.filter((p) => p.status === PoolStatus.Active).length} Active
            </Badge>
          </div>
        </div>

        {/* Stats */}
        <div className="grid sm:grid-cols-4 gap-4">
          <Card>
            <CardContent className="flex items-center gap-4 py-4">
              <div className="w-12 h-12 bg-primary/10 rounded-full flex items-center justify-center">
                <Building2 className="h-6 w-6 text-primary" />
              </div>
              <div>
                <p className="text-2xl font-bold">{MOCK_PROJECTS.length}</p>
                <p className="text-sm text-text-muted">Total Projects</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="flex items-center gap-4 py-4">
              <div className="w-12 h-12 bg-secondary/10 rounded-full flex items-center justify-center">
                <DollarSign className="h-6 w-6 text-secondary" />
              </div>
              <div>
                <p className="text-2xl font-bold">
                  {formatUsd(
                    aptToUsd(octasToApt(MOCK_PROJECTS.reduce((acc, p) => acc + p.currentFunding, 0)))
                  )}
                </p>
                <p className="text-sm text-text-muted">USD Raised</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="flex items-center gap-4 py-4">
              <div className="w-12 h-12 bg-success/10 rounded-full flex items-center justify-center">
                <Clock className="h-6 w-6 text-success" />
              </div>
              <div>
                <p className="text-2xl font-bold">
                  {formatNumber(MOCK_PROJECTS.reduce((acc, p) => acc + p.currentHours, 0), 0)}
                </p>
                <p className="text-sm text-text-muted">Hours Contributed</p>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="flex items-center gap-4 py-4">
              <div className="w-12 h-12 bg-warning/10 rounded-full flex items-center justify-center">
                <Users className="h-6 w-6 text-warning" />
              </div>
              <div>
                <p className="text-2xl font-bold">
                  {MOCK_PROJECTS.filter((p) => p.status === PoolStatus.Funded || p.status === PoolStatus.Completed).length}
                </p>
                <p className="text-sm text-text-muted">Completed</p>
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Filters */}
        <Card>
          <CardContent className="pt-6">
            <div className="flex flex-col sm:flex-row gap-4">
              <div className="relative flex-1">
                <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-text-muted" />
                <Input
                  placeholder="Search projects..."
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  className="pl-10"
                />
              </div>
              <Select value={statusFilter} onValueChange={setStatusFilter}>
                <SelectTrigger className="w-full sm:w-40">
                  <SelectValue placeholder="Status" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Status</SelectItem>
                  {Object.entries(PoolStatusLabels).map(([key, label]) => (
                    <SelectItem key={key} value={key}>
                      {label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <Select value={categoryFilter} onValueChange={setCategoryFilter}>
                <SelectTrigger className="w-full sm:w-40">
                  <SelectValue placeholder="Category" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Categories</SelectItem>
                  {categories.map((category) => (
                    <SelectItem key={category} value={category}>
                      {category}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </CardContent>
        </Card>

        {/* Projects Grid */}
        {filteredProjects.length === 0 ? (
          <Card>
            <CardContent className="text-center py-12">
              <Building2 className="h-12 w-12 mx-auto mb-4 text-text-muted opacity-30" />
              <p className="text-text-muted">No projects found</p>
              <p className="text-sm text-text-muted mt-1">
                Try adjusting your search or filters
              </p>
            </CardContent>
          </Card>
        ) : (
          <div className="grid md:grid-cols-2 gap-6">
            {filteredProjects.map((project) => {
              const fundingProgress = calculatePercentage(
                project.currentFunding,
                project.targetFunding
              );
              const hoursProgress = calculatePercentage(
                project.currentHours,
                project.targetHours
              );

              return (
                <Link key={project.id} href={`/projects/${project.id}`}>
                  <Card hoverable className="h-full overflow-hidden">
                    {/* Project Image/Placeholder */}
                    <div className="h-48 bg-gradient-to-br from-primary/20 to-secondary/20 flex items-center justify-center">
                      <Building2 className="h-16 w-16 text-primary/40" />
                    </div>
                    
                    <CardHeader>
                      <div className="flex items-start justify-between gap-2">
                        <div>
                          <Badge variant={getStatusBadgeVariant(project.status)} className="mb-2">
                            {PoolStatusLabels[project.status]}
                          </Badge>
                          <CardTitle className="text-lg">{project.name}</CardTitle>
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
                            <DollarSign className="h-4 w-4" />
                            Funding
                          </span>
                          <span>
                            {formatUsd(aptToUsd(octasToApt(project.currentFunding)))} / {formatUsd(aptToUsd(octasToApt(project.targetFunding)))}
                          </span>
                        </div>
                        <Progress value={fundingProgress} className="h-2" />
                      </div>

                      {/* Hours Progress */}
                      <div>
                        <div className="flex justify-between text-sm mb-1">
                          <span className="flex items-center gap-1">
                            <Clock className="h-4 w-4" />
                            Service Hours
                          </span>
                          <span>
                            {project.currentHours} / {project.targetHours}
                          </span>
                        </div>
                        <Progress value={hoursProgress} className="h-2" indicatorClassName="bg-secondary" />
                      </div>

                      <div className="flex items-center justify-between pt-2">
                        <Badge variant="outline">{project.category}</Badge>
                        <span className="text-sm text-primary flex items-center gap-1">
                          View Details
                          <ArrowRight className="h-4 w-4" />
                        </span>
                      </div>
                    </CardContent>
                  </Card>
                </Link>
              );
            })}
          </div>
        )}
      </div>
    </MainLayout>
  );
}

