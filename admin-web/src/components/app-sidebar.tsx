"use client"

import * as React from "react"
import {
  IconDashboard,
  IconFileDescription,
  IconInnerShadowTop,
  IconFileTextFilled,
} from "@tabler/icons-react"

import { NavMain } from "@/components/nav-main"

import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarRail,
} from "@/components/ui/sidebar"

// const data = {
//   user: {
//     name: "GenAI Admin",
//     email: "admin@genai.com",
//     avatar: "/avatars/admin.jpg",
//   },
//   navMain: [
//     {
//       title: "Dashboard",
//       url: "/dashboard",
//       icon: IconDashboard,
//     },
//     {
//       title: "Summarizer",
//       url: "/summarizer",
//       icon: IconFileDescription,
//     },
//     {
//       title: "Prompts",
//       url: "/prompts",
//       icon: IconFileTextFilled,
//     },
//   ],
// }

// This is sample data.
const data = {
    versions: ["1.0.1", "1.1.0-alpha", "2.0.0-beta1"],
    navMain: [
      {
        title: "General",
        url: "#",
        items: [
          {
            title: "Dashboard",
            url: "/dashboard",
            icon: IconDashboard,
          },
        ],
      },
      {
        title: "Summarizer",
        url: "#",
        items: [
          {
            title: "Upload File",
            url: "/summarizer/upload",
          },
          {
            title: "Files Processed",
            url: "/summarizer/files-processed",
          },
        ],
      },
      {
        title: "Prompt Manager",
        url: "#",
        items: [
          {
            title: "Create Prompt",
            url: "/prompts/create",
          },
          {
            title: "Prompts List",
            url: "/prompts/list",
          },
        ],
      },
    ],
  }

export function AppSidebar({ ...props }: React.ComponentProps<typeof Sidebar>) {
  return (
    <Sidebar collapsible="offcanvas" {...props}>
      <SidebarHeader>
        <SidebarMenu>
          <SidebarMenuItem>
            <SidebarMenuButton
              asChild
              className="data-[slot=sidebar-menu-button]:!p-1.5"
            >
              <a href="/">
                <IconInnerShadowTop className="!size-5" />
                <span className="text-base font-semibold">GenAI Admin</span>
              </a>
            </SidebarMenuButton>
          </SidebarMenuItem>
        </SidebarMenu>
      </SidebarHeader>
      {/* <SidebarContent>
        <NavMain items={data.navMain} />
      </SidebarContent> */}
      <SidebarContent>
        {/* We create a SidebarGroup for each parent. */}
        {data.navMain.map((item) => (
          <SidebarGroup key={item.title}>
            <SidebarGroupLabel>{item.title}</SidebarGroupLabel>
            <SidebarGroupContent>
              <SidebarMenu>
                {item.items.map((item) => (
                  <SidebarMenuItem key={item.title}>
                    <SidebarMenuButton asChild isActive={item.isActive}>
                      <a href={item.url}>{item.title}</a>
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                ))}
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        ))}
      </SidebarContent>
      <SidebarRail />
      <SidebarFooter>
      </SidebarFooter>
    </Sidebar>
  )
}
