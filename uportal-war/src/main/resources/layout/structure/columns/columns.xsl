<?xml version="1.0" encoding="utf-8"?>
<!--

    Licensed to Apereo under one or more contributor license
    agreements. See the NOTICE file distributed with this work
    for additional information regarding copyright ownership.
    Apereo licenses this file to you under the Apache License,
    Version 2.0 (the "License"); you may not use this file
    except in compliance with the License.  You may obtain a
    copy of the License at the following location:

      http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing,
    software distributed under the License is distributed on an
    "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
    KIND, either express or implied.  See the License for the
    specific language governing permissions and limitations
    under the License.

-->
<xsl:stylesheet version="1.0" xmlns:dlm="http://www.uportal.org/layout/dlm" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

    <xsl:param name="userLayoutRoot">root</xsl:param>
    <xsl:param name="focusedTabID">none</xsl:param>
    <xsl:param name="defaultTab">1</xsl:param>
    <xsl:param name="detached">false</xsl:param>
    <xsl:param name="userImpersonating">false</xsl:param>

    <!-- Check if we have favorites or not -->
    <xsl:variable name="hasFavorites">
        <xsl:choose>
            <xsl:when test="layout/folder/folder[@type='favorites']">true</xsl:when>
            <xsl:otherwise>false</xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <!-- Used to build the tabGroupsList:  discover tab groups, add each to the list ONLY ONCE -->
    <xsl:key name="tabGroupKey" match="layout/folder/folder[@hidden='false' and @type='regular']" use="@tabGroup"/>
    <!-- Used to build the sidebarGroupsList:  discover sidebar groups, add each to the list ONLY ONCE -->
    <xsl:key name="sidebarGroupKey" match="layout/folder/folder[@hidden='false' and @type='sidebar']" use="@name"/>

    <xsl:variable name="activeTabIdx">
        <!-- if the activeTab is a number then it is the active tab index -->
        <!-- otherwise it is the ID of the active tab. If it is the ID -->
        <!-- then check to see if that tab is still in the layout and -->
        <!-- if so use its index. if not then default to an index of 1. -->
        <xsl:choose>
            <xsl:when test="$focusedTabID!='none' and /layout/folder/folder[@ID=$focusedTabID and @type='regular' and @hidden='false']">
                <xsl:value-of select="count(/layout/folder/folder[@ID=$focusedTabID]/preceding-sibling::folder[@type='regular' and @hidden='false'])+1"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$defaultTab" />
            </xsl:otherwise> <!-- if not found, use first tab -->
        </xsl:choose>
    </xsl:variable>

    <xsl:variable name="activeTabID" select="/layout/folder/folder[@type='regular'and @hidden='false'][position() = $activeTabIdx]/@ID"/>

    <!-- focusedFolderId is the focusedTabID param IF (1) that value points to a
         folder of type 'favorite_collection' AND (2) the user is not focusing on
         a single portlet (i.e. not in 'focused mode'); otherwise it's 'none'  :) -->
    <xsl:variable name="focusedFolderId">
        <xsl:choose>
            <xsl:when test="not(//folder/channel[@ID = $userLayoutRoot])
                            and /layout/folder/folder[@ID=$focusedTabID and @type='favorite_collection']">
                <xsl:value-of select="/layout/folder/folder[@ID=$focusedTabID and @type!='regular']/@ID"/>
            </xsl:when>
            <xsl:otherwise>none</xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <!-- Evaluate the 'activeTabGroup' (optional feature) -->
    <xsl:variable name="activeTabGroup">
        <xsl:choose>
            <xsl:when test="//folder[@ID=$activeTabID]/@tabGroup">
                <xsl:value-of select="//folder[@ID=$activeTabID]/@tabGroup"/>
            </xsl:when>
            <xsl:otherwise>DEFAULT_TABGROUP</xsl:otherwise>
        </xsl:choose>
    </xsl:variable>

    <!-- ROOT template.  Chooses between templates that produce <layout_fragment> 
         (in DETACHED window state) and simply <layout> (in the general case). -->
    <xsl:template match="layout">
        <xsl:choose>
            <xsl:when test="$userLayoutRoot != 'root' and $detached = 'true'">
                <xsl:apply-templates select="folder[@type='root']" mode="DETACHED" />
            </xsl:when>
            <xsl:otherwise>
                <xsl:apply-templates select="folder[@type='root']" mode="NORMAL" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- NORMAL page template.  Governs the overall structure when the page is 
         non-detached. -->
    <xsl:template match="folder[@type='root']" mode="NORMAL">
        <layout>
            <xsl:call-template name="debug-info"/>

            <xsl:if test="/layout/@dlm:fragmentName">
                <xsl:attribute name="dlm:fragmentName"><xsl:value-of select="/layout/@dlm:fragmentName"/></xsl:attribute>
            </xsl:if>

            <!-- For each channel that will display on the page, add a channel-header element so the channel will be
                 invoked if it supports the RENDER_HEADERS phase to insert content in the page HEAD section.
                 Sidebar is a feature in Universality to list portlets as a set of links and as such the portlets
                 are not actually rendered and should not be included.  -->
            <!-- Note: Currently include support for universality legacy types header and footer though these really
                 aren't used anymore and are obsolete as of uP 4.1 with Respondr support for regions.
                 Remove legacy items in uP 4.2 or later.  James W 4/14 -->
            <header>
                <!-- Display channel-headers for channels in regions (legacy: also folders of type header and
                     footer). Exclude channels in the special folders sidebar, _favorites and favorite_collection
                     as they are not actually rendered on the page. -->
                <!-- Note: With default quick start data set using Universality or mUniversality theme, uPortal log file
                     will have warnings for dynamicSkinPortlet (fname=dynamic-respondr-skin) being invoked for both
                     RENDER phases but results not being included by the theme because the data set has portlets
                     in regions (for Respondr use). If a site is using universality and not respondr, their
                     layout-fragments should not have regions in them and they should not include dynamic-respondr-skin.
                     However it is convenient for us to have regions in the default data set to test switching back and
                     forth between universality and Respondr. -->
                <xsl:for-each select="child::folder[@type!='regular' and @type!='sidebar' and @type!='favorites' and @type!='favorite_collection']/descendant::channel">
                    <channel-header ID="{@ID}"/>
                </xsl:for-each>
                <!-- Legacy: insert portlet content in channels in folders of type header into the head output.
                     As of uP 4.1 standard practice is for portlets to support RENDER_HEADERS subphase. See Dynamic
                     Skin Portlet for an example of usage.  Remove header/footer support in uP 4.2. James W 4/14 -->
                <xsl:for-each select="child::folder[@type='header']">
                    <xsl:copy-of select=".//channel"/>
                </xsl:for-each>

                <xsl:choose>
                    <xsl:when test="$focusedFolderId != 'none'">
                        <!-- Display channel-headers for channels visible on the selected tab (using externalId for tab name). -->
                        <xsl:for-each select="child::folder[@ID = $focusedFolderId]/descendant::channel">
                            <channel-header ID="{@ID}"/>
                        </xsl:for-each>
                    </xsl:when>
                    <xsl:when test="$userLayoutRoot = 'root'">
                        <!-- Display channel-headers for channels visible on the selected tab. -->
                        <xsl:for-each select="folder[@ID = $activeTabID and @type='regular' and @hidden='false']/descendant::channel">
                            <channel-header ID="{@ID}"/>
                        </xsl:for-each>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- Display channel-header for only focused channel -->
                        <channel-header ID="{$userLayoutRoot}"/>
                    </xsl:otherwise>
                </xsl:choose>
            </header>

            <regions>
                <xsl:choose>
                    <xsl:when test="$userLayoutRoot = 'root'">
                        <!-- Include all regions when in DASHBOARD mode -->
                        <xsl:for-each select="child::folder[@type!='regular' and @type!='sidebar' and channel]"><!-- Ignores empty folders -->
                            <xsl:call-template name="region"/>
                        </xsl:for-each>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- Include all regions EXCEPT 'region-customize' when in FOCUSED mode -->
                        <xsl:for-each select="child::folder[@type!='customize' and @type!='regular' and @type!='sidebar' and channel]"><!-- Ignores empty folders -->
                            <xsl:call-template name="region"/>
                        </xsl:for-each>
                    </xsl:otherwise>
                </xsl:choose>

            </regions>

            <xsl:choose>
                <xsl:when test="$focusedFolderId != 'none'"><xsl:call-template name="tabListfocusedFolder"/></xsl:when>
                <xsl:otherwise><xsl:call-template name="tabList"/></xsl:otherwise>
            </xsl:choose>

            <content>
                <xsl:attribute name="hasFavorites"><xsl:value-of select="$hasFavorites" /></xsl:attribute>
                <xsl:choose>
                    <xsl:when test="$focusedFolderId != 'none'">
                        <xsl:apply-templates select="folder[@ID=$focusedFolderId]"/>
                    </xsl:when>
                    <xsl:when test="$userLayoutRoot = 'root'">
                        <xsl:apply-templates select="folder[@type='regular' and @hidden='false']"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <focused>
                            <!-- Detect whether a focused channel is present in the user's layout -->
                            <xsl:attribute name="in-user-layout">
                                <xsl:choose>
                                    <xsl:when test="//folder[@type='regular' and @hidden='false']/channel[@ID = $userLayoutRoot]">yes</xsl:when>
                                    <xsl:otherwise>no</xsl:otherwise>
                                </xsl:choose>
                            </xsl:attribute>
                            <xsl:apply-templates select="//*[@ID = $userLayoutRoot]"/>
                        </focused>
                    </xsl:otherwise>
                </xsl:choose>
            </content>

            <xsl:call-template name="sidebarList"/>
            <xsl:call-template name="footer" />
            <xsl:call-template name="favorites" />
        </layout>
    </xsl:template>

    <!-- DETACHED page template.  Governs the overall structure when the page is 
         rendering a portlet in detached window state. -->
    <xsl:template match="folder[@type='root']" mode="DETACHED">
        <layout_fragment>
            <xsl:call-template name="debug-info"/>
            <xsl:call-template name="tabList"/>
            <!-- For each channel that will display on the page, add a channel-header element so the channel will be
                 invoked if it supports the RENDER_HEADERS phase to insert content in the page HEAD section. -->
            <header>
                <!-- For detached mode, include regions hidden-top, page-top, page-bottom, and hidden-bottom. -->
                <xsl:for-each select="child::folder[@type='hidden-top' or @type='page-top' or @type='page-bottom' or @type='hidden-bottom']/descendant::channel">
                    <channel-header ID="{@ID}"/>
                </xsl:for-each>
                <!-- Include the channel that is shown in detached mode. -->
                <channel-header ID="{$userLayoutRoot}"/>
            </header>
            <regions>
                <!-- For detached mode, include regions hidden-top, page-top, page-bottom, and hidden-bottom. -->
                <xsl:for-each select="child::folder[@type='hidden-top' or @type='page-top' or @type='page-bottom' or @type='hidden-bottom']">
                    <xsl:call-template name="region"/>
                </xsl:for-each> 
            </regions>
            <content>
                <xsl:attribute name="hasFavorites"><xsl:value-of select="$hasFavorites" /></xsl:attribute>
                <!-- Detect whether a detached channel is present in the user's layout ? -->
                <xsl:apply-templates select="//*[@ID = $userLayoutRoot]"/>
            </content>
        </layout_fragment>
    </xsl:template>

    <xsl:template name="debug-info">
        <!-- This element is not (presently) consumed by the theme transform, but it can be written to the logs easy debugging -->
        <debug>
            <userLayoutRoot><xsl:value-of select="$userLayoutRoot"></xsl:value-of></userLayoutRoot>
            <focusedTabID><xsl:value-of select="$focusedTabID"></xsl:value-of></focusedTabID>
            <focusedFolderId><xsl:value-of select="$focusedFolderId"/></focusedFolderId>
            <hasFavorites><xsl:value-of select="$hasFavorites"/></hasFavorites>
            <defaultTab><xsl:value-of select="$defaultTab"></xsl:value-of></defaultTab>
            <detached><xsl:value-of select="$detached"></xsl:value-of></detached>
            <activeTabIdx><xsl:value-of select="$activeTabIdx"></xsl:value-of></activeTabIdx>
            <activeTabID><xsl:value-of select="$activeTabID"></xsl:value-of></activeTabID>
            <activeTabGroup><xsl:value-of select="$activeTabGroup"></xsl:value-of></activeTabGroup>
            <tabsInTabGroup><xsl:value-of select="count(/layout/folder/folder[@tabGroup=$activeTabGroup and @type='regular' and @hidden='false'])"/></tabsInTabGroup>
            <userImpersonation><xsl:value-of select="$userImpersonating"/></userImpersonation>
        </debug>
    </xsl:template>

    <!-- 
     | Regions and Roles
     | =================
     | The <regions> section allows non-regular, non-sidebar portlets to appear in the
     | output page, even in focused mode.  In Universality this is done with a 'role' 
     | attribute on the portlet publication record.
     |
     | In Respondr, this is done through regions: folders with a type attribute _other than_
     | 'root', 'regular', or 'sidebar' (for legacy support).  Any folder type beyond these
     | three automatically becomes a region.  Respondr is responsible for recognizing
     | region-based portlets and placing them appropriately on the page.  Note that a region
     | name can appear multiple times in the output;  this approach allows multiple
     | fragments to place portlets in the same region.
     |
     | Regions behave normally in dashboard (normal) and focused (maximized) mode;  in
     | DETACHED window state, only a few regions are processed, and then ONLY IF THE STICKY
     | HEADER option is in effect.  The list of regions included with a sticky-header is:
     | hidden-top, page-top, page-bottom, hidden-bottom.  The remaining regions are not
     | present in the DOM and therefore their portlets MUST NOT be added to the rendering
     | queue. 
     +-->
    <xsl:template name="region">
        <region name="{@type}">
            <xsl:copy-of select="channel"/>
        </region>
    </xsl:template>

    <xsl:template name="tabList">
        <navigation>
            <!-- Signals that add-tab prompt is appropriate in the context of this navigation
                 user might or might not actually have permission to add a tab, which is evaluated later (in the theme) -->
            <xsl:attribute name="allowAddTab">true</xsl:attribute>
            <!-- The tabGroups (optional feature) -->
            <tabGroupsList>
                <xsl:attribute name="activeTabGroup">
                    <xsl:value-of select="$activeTabGroup"/>
                </xsl:attribute>
                <xsl:for-each select="/layout/folder/folder[@type='regular' and @hidden='false']"><!-- These are standard tabs -->
                    <!-- Process only the first tab in each Tab Group (avoid duplicates) -->
                    <xsl:if test="self::node()[generate-id() = generate-id(key('tabGroupKey',@tabGroup)[1])]">
                        <tabGroup name="{@tabGroup}" firstTabId="{@ID}">
                            <xsl:value-of select="@tabGroup"/>
                        </tabGroup>
                    </xsl:if>
                </xsl:for-each>
            </tabGroupsList>
            <!-- The tabs -->
            <xsl:for-each select="/layout/folder/folder[@type='regular' and @hidden='false']">
                <xsl:call-template name="tab" />
            </xsl:for-each>
        </navigation>
    </xsl:template>

    <xsl:template name="tabListfocusedFolder">
        <navigation>
            <!-- signals that add-tab prompt is not appropriate in the context of this navigation -->
            <xsl:attribute name="allowAddTab">false</xsl:attribute>

            <!-- just the one focused-on tab -->
            <xsl:for-each select="/layout/folder/folder[@ID = $focusedFolderId]">
                <xsl:call-template name="tab"/>
            </xsl:for-each>
        </navigation>
    </xsl:template>

    <!-- Folders of type sidebar is a legacy item from uPortal 2.x days that per Drew is not really used as far as he knows.
         This is a good candidate for removal when Respondr has traction since it handles sidebar-left and sidebar-right
         much more gracefully. James W 4/14 -->
    <xsl:template name="sidebarList">
        <sidebar>
            <!-- To define sidebar elements - hidden from navigation but shown in sidebar and herited from DLM and ordered by precedence on tab-->
            <xsl:for-each select="/layout/folder/folder[@type='sidebar' and @hidden='false' and generate-id() = generate-id(key('sidebarGroupKey',@name)[1])]">
                <xsl:sort select="number(@dlm:precedence)" order="descending"/>
                <sidebarGroup name="{@name}">
                    <xsl:for-each select="key('sidebarGroupKey',@name)">
                        <xsl:sort select="number(@dlm:precedence)" order="descending"/>
                        <xsl:for-each select="descendant::channel">
                            <xsl:sort select="number(@dlm:precedence)" order="descending"/>
                            <sidebarChannel name="{@name}" title="{@title}" ID="{@ID}" fname="{@fname}" description="{@description}">
                                <xsl:choose>
                                    <xsl:when test="parameter[@name='PORTLET.alternativeMaximixedLink']">
                                        <xsl:attribute name="alternativeMaximixedLink">
                                            <xsl:value-of select="parameter[@name='PORTLET.alternativeMaximixedLink']/@value"/>
                                        </xsl:attribute>
                                    </xsl:when>
                                    <xsl:when test="parameter[@name='alternativeMaximixedLink']">
                                        <xsl:attribute name="alternativeMaximixedLink">
                                            <xsl:value-of select="parameter[@name='alternativeMaximixedLink']/@value"/>
                                        </xsl:attribute>
                                    </xsl:when>
                                </xsl:choose>
                            </sidebarChannel>
                        </xsl:for-each>
                    </xsl:for-each>
                </sidebarGroup>
            </xsl:for-each>
        </sidebar>
    </xsl:template>

    <xsl:template match="folder[@type!='root' and @hidden='false']">
        <xsl:attribute name="type">regular</xsl:attribute>
        <xsl:if test="$activeTabID = @ID or $focusedFolderId = @ID">
            <xsl:if test="child::folder">
                <xsl:for-each select="folder">
                    <column>
                        <xsl:attribute name="ID">
                            <xsl:value-of select="@ID"/>
                        </xsl:attribute>
                        <xsl:attribute name="priority">
                            <xsl:value-of select="@priority"/>
                        </xsl:attribute>
                        <xsl:attribute name="width">
                            <xsl:value-of select="@width"/>
                        </xsl:attribute>
                        <xsl:if test="@dlm:moveAllowed = 'false'">
                            <xsl:attribute name="dlm:moveAllowed">false</xsl:attribute>
                        </xsl:if>
                        <xsl:if test="@dlm:deleteAllowed = 'false'">
                            <xsl:attribute name="dlm:deleteAllowed">false</xsl:attribute>
                        </xsl:if>
                        <xsl:if test="@dlm:editAllowed = 'false'">
                            <xsl:attribute name="dlm:editAllowed">false</xsl:attribute>
                        </xsl:if>
                        <xsl:if test="@dlm:addChildAllowed = 'false'">
                            <xsl:attribute name="dlm:addChildAllowed">false</xsl:attribute>
                        </xsl:if>
                        <xsl:if test="@dlm:precedence > 0">
                            <xsl:attribute name="dlm:precedence">
                                <xsl:value-of select="@dlm:precedence"/>
                            </xsl:attribute>
                        </xsl:if>
                        <xsl:apply-templates/>
                    </column>
                </xsl:for-each>
            </xsl:if>
            <xsl:if test="child::channel">
                <column>
                    <xsl:apply-templates/>
                </column>
            </xsl:if>
        </xsl:if>
    </xsl:template>

    <xsl:template name="tab">
        <tab>
            <!-- Copy folder attributes verbatim -->
            <xsl:for-each select="attribute::*">
                <xsl:attribute name="{name()}"><xsl:value-of select="."/></xsl:attribute>
            </xsl:for-each>
            <xsl:if test="@ID = $focusedFolderId">
                <xsl:attribute name="focusedFolder">true</xsl:attribute>
            </xsl:if>
            <xsl:if test="count(./folder[not(@dlm:addChildAllowed='false')]) >0">
                <xsl:attribute name="dlm:hasColumnAddChildAllowed">true</xsl:attribute>
            </xsl:if>

            <!-- Add 'activeTab' and 'activeTabPosition' attributes as appropriate -->
            <xsl:choose>
                <xsl:when test="$activeTabID = @ID">
                    <xsl:attribute name="activeTab">true</xsl:attribute>
                    <xsl:attribute name="activeTabPosition"><xsl:value-of select="$activeTabID"/></xsl:attribute>
                </xsl:when>
                <xsl:when test="$focusedFolderId = @ID">
                    <xsl:attribute name="activeTab">true</xsl:attribute>
                    <!-- the focused fragment will be the only tab, so index 1 is the position of the active tab -->
                    <xsl:attribute name="activeTabPosition">1</xsl:attribute>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:attribute name="activeTab">false</xsl:attribute>
                </xsl:otherwise>
            </xsl:choose>

            <xsl:for-each select="./descendant::channel">
                <tabChannel name="{@name}" title="{@title}" ID="{@ID}" fname="{@fname}" description="{@description}">
                    <xsl:choose>
                        <xsl:when test="parameter[@name='PORTLET.quicklink']">
                            <xsl:attribute name="quicklink">
                                <xsl:value-of select="parameter[@name='PORTLET.quicklink']/@value"/>
                            </xsl:attribute>
                        </xsl:when>
                        <xsl:when test="parameter[@name='quicklink']">
                            <xsl:attribute name="quicklink">
                                <xsl:value-of select="parameter[@name='quicklink']/@value"/>
                            </xsl:attribute>
                        </xsl:when>
                    </xsl:choose>
                    <xsl:choose>
                        <xsl:when test="parameter[@name='PORTLET.qID']">
                            <xsl:attribute name="qID">
                                <xsl:value-of select="parameter[@name='PORTLET.qID']/@value"/>
                            </xsl:attribute>
                        </xsl:when>
                        <xsl:when test="parameter[@name='qID']">
                            <xsl:attribute name="qID">
                                <xsl:value-of select="parameter[@name='qID']/@value"/>
                            </xsl:attribute>
                        </xsl:when>
                    </xsl:choose>
                    <xsl:choose>
                        <xsl:when test="parameter[@name='PORTLET.removeFromLayout']">
                            <xsl:attribute name="removeFromLayout">
                                <xsl:value-of select="parameter[@name='PORTLET.removeFromLayout']/@value"/>
                            </xsl:attribute>
                        </xsl:when>
                        <xsl:when test="parameter[@name='removeFromLayout']">
                            <xsl:attribute name="removeFromLayout">
                                <xsl:value-of select="parameter[@name='removeFromLayout']/@value"/>
                            </xsl:attribute>
                        </xsl:when>
                    </xsl:choose>
                    <xsl:choose>
                        <xsl:when test="parameter[@name='PORTLET.alternativeMaximixedLink']">
                            <xsl:attribute name="alternativeMaximixedLink">
                                <xsl:value-of select="parameter[@name='PORTLET.alternativeMaximixedLink']/@value"/>
                            </xsl:attribute>
                        </xsl:when>
                        <xsl:when test="parameter[@name='alternativeMaximixedLink']">
                            <xsl:attribute name="alternativeMaximixedLink">
                                <xsl:value-of select="parameter[@name='alternativeMaximixedLink']/@value"/>
                            </xsl:attribute>
                        </xsl:when>
                    </xsl:choose>
                </tabChannel>
            </xsl:for-each>
        </tab>
    </xsl:template>

    <!-- List of Favorites
     |   =================
     |   A list of favorited channels. 
     |   To be utilized to establish if "add to favorites" 
     |   or "remove from favorites" shows in the options menu -->
    <xsl:template name="favorites">
        <favorites>
            <xsl:for-each select="/layout/folder/folder[@type='favorites']/folder/channel">
                <favorite fname='{@fname}'/>
            </xsl:for-each>
            <xsl:for-each select="/layout/folder/folder[@type='favorite_collection']/folder/channel">
                <favorite fname='{@fname}'/>
            </xsl:for-each>
        </favorites>
    </xsl:template>

    <xsl:template match="channel">
        <xsl:choose>
            <xsl:when test="$userImpersonating = 'true' and parameter[@name='blockImpersonation']/@value = 'true'">
                <blocked-channel>
                    <xsl:copy-of select="@*"/>
                    <xsl:copy-of select="child::*"/>
                </blocked-channel>
            </xsl:when>
            <xsl:otherwise>
                <xsl:copy-of select="."/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template match="parameter">
        <xsl:copy-of select="."/>
    </xsl:template>

    <!-- Folders of type footer is a legacy item from uPortal 2.x days that per Drew is not used much as far as he knows.
         This is a good candidate for removal when Respondr has traction since it handles footer and page bottom
         much more gracefully. James W 4/14 -->
    <xsl:template name="footer">
        <footer>
            <xsl:for-each select="child::folder[attribute::type='footer']">
                <xsl:copy-of select=".//channel"/>
            </xsl:for-each>
        </footer>
    </xsl:template>

</xsl:stylesheet>
